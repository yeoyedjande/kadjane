import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';
import 'package:kadjane/features/draw/presentation/widgets/draw_wheel.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Action choisie par l'utilisateur dans la fenêtre de félicitations.
enum _CelebrationAction { viewBeneficiary, close }

/// Écran immersif du tirage au sort.
///
/// Déroulé : le bénéficiaire est calculé par le moteur de tirage **avant**
/// toute animation ; la roue tourne ensuite jusqu'à placer le gagnant sous la
/// flèche, et la fenêtre de félicitations ne s'ouvre qu'une fois la roue
/// immobilisée.
class DrawScreen extends ConsumerStatefulWidget {
  const DrawScreen({required this.tontineId, required this.cycleId, super.key});

  final String tontineId;
  final String cycleId;

  @override
  ConsumerState<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends ConsumerState<DrawScreen>
    with SingleTickerProviderStateMixin {
  /// Temps de contemplation entre l'arrêt de la roue et la célébration.
  static const Duration _revealPause = Duration(milliseconds: 700);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KDurations.wheelSpin,
  );
  Animation<double> _rotation = const AlwaysStoppedAnimation<double>(0);

  bool _isSpinning = false;
  DrawSession? _result;

  /// Participants affichés sur la roue pendant et après la rotation.
  ///
  /// Ils sont figés au moment du tirage : le gagnant sortant de la liste des
  /// éligibles, la roue doit continuer d'afficher la composition d'origine.
  List<String>? _frozenLabels;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run({
    required TontineCycle cycle,
    required String amountLabel,
    required bool override,
    String? overrideReason,
  }) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null || _isSpinning) {
      return;
    }

    setState(() => _isSpinning = true);
    try {
      // 1. Le bénéficiaire est déterminé ici, jamais par l'animation.
      final DrawSession session = await ref
          .read(drawRepositoryProvider)
          .run(
            RunDrawCommand(
              tontineId: widget.tontineId,
              cycleId: widget.cycleId,
              actorMemberId: actor.id,
              override: override,
              overrideReason: overrideReason,
            ),
          );

      // 2. La roue s'aligne sur le résultat déjà connu.
      final int winnerIndex = session.participants.indexWhere(
        (DrawParticipant p) => p.participantId == session.winnerParticipantId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _frozenLabels = session.participants
            .map((DrawParticipant p) => p.displayName)
            .toList(growable: false);
        _rotation =
            Tween<double>(
              begin: 0,
              end: DrawWheel.targetAngleFor(
                winnerIndex: winnerIndex < 0 ? 0 : winnerIndex,
                count: session.participants.length,
              ),
            ).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
            );
      });

      // 3. Rotation visible à l'écran jusqu'à l'arrêt sous la flèche.
      await _controller.forward(from: 0);
      await Future<void>.delayed(_revealPause);
      if (!mounted) {
        return;
      }

      setState(() {
        _result = session;
        _isSpinning = false;
      });
      ref.invalidate(tontineDetailProvider(widget.tontineId));
      refreshOrganizationData(ref);

      // 4. Célébration, une fois la roue immobile.
      await _celebrate(session: session, amountLabel: amountLabel);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _isSpinning = false);
        context.showMessage(
          ErrorMapper.message(context.l10n, error),
          isError: true,
        );
      }
    }
  }

  Future<void> _celebrate({
    required DrawSession session,
    required String amountLabel,
  }) async {
    final _CelebrationAction? action = await showDialog<_CelebrationAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) =>
          _DrawCelebrationDialog(session: session, amountLabel: amountLabel),
    );
    if (!mounted || action != _CelebrationAction.viewBeneficiary) {
      return;
    }
    context.pushReplacement(
      AppRoutes.tontineBeneficiary(widget.tontineId, widget.cycleId),
    );
  }

  Future<void> _confirmAndRun(TontineCycle cycle, String amountLabel) async {
    final bool confirmed = await KConfirmDialog.show(
      context,
      title: context.l10n.drawConfirmTitle,
      message: context.l10n.drawConfirmMessage,
      confirmLabel: context.l10n.commonConfirm,
      icon: Icons.casino_outlined,
    );
    if (confirmed) {
      await _run(cycle: cycle, amountLabel: amountLabel, override: false);
    }
  }

  Future<void> _forceAndRun(TontineCycle cycle, String amountLabel) async {
    final String? reason = await KReasonDialog.show(
      context,
      title: context.l10n.drawOverrideTitle,
      message: context.l10n.drawOverrideMessage,
      fieldLabel: context.l10n.drawOverrideReason,
      confirmLabel: context.l10n.commonConfirm,
    );
    if (reason != null) {
      await _run(
        cycle: cycle,
        amountLabel: amountLabel,
        override: true,
        overrideReason: reason,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TontineDetailData> detail = ref.watch(
      tontineDetailProvider(widget.tontineId),
    );
    final bool canRun = ref.watch(canProvider(Permission.drawRun));
    final bool canOverride = ref.watch(canProvider(Permission.drawOverride));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.drawTitle)),
      body: KAsyncView<TontineDetailData>(
        value: detail,
        onRetry: () => ref.invalidate(tontineDetailProvider(widget.tontineId)),
        builder: (TontineDetailData data) {
          final TontineCycle cycle = data.cycles.firstWhere(
            (TontineCycle c) => c.id == widget.cycleId,
            orElse: () => data.cycles.first,
          );
          final List<TontineParticipant> eligible = data.participants
              .where(
                (TontineParticipant p) =>
                    p.isActive && p.isEligibleForDraw && !p.hasReceivedPot,
              )
              .toList(growable: false);
          final DrawEligibility eligibility =
              data.eligibility ??
              const DrawEligibility(
                allowed: false,
                reason: DrawBlockReason.tontineNotActive,
                missingContributions: 0,
                canOverride: false,
              );
          final bool alreadyDrawn = data.beneficiaryOf(cycle.id) != null;
          final String amountLabel = MoneyFormatter.format(
            cycle.expectedAmount,
            data.tontine.currency,
          );

          // Pendant et après la rotation, la roue conserve sa composition.
          final List<String> labels =
              _frozenLabels ??
              eligible
                  .map((TontineParticipant p) => p.displayName)
                  .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.xxxl,
            ),
            children: <Widget>[
              Text(
                DateFormatter.periodLabel(
                  cycle.periodStart,
                  context.localeCode,
                ),
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                data.tontine.name,
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              KSpacing.gapLg,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _DrawStat(
                    value: '${data.participants.length}',
                    label: context.l10n.tontinesParticipants,
                  ),
                  _DrawStat(
                    value: '${labels.length}',
                    label: context.l10n.drawEligibleParticipants,
                  ),
                  _DrawStat(
                    value: MoneyFormatter.compact(
                      cycle.expectedAmount,
                      data.tontine.currency,
                    ),
                    label: context.l10n.tontinesPot,
                  ),
                ],
              ),
              KSpacing.gapXl,
              if (labels.isEmpty)
                KEmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: context.l10n.drawNoEligible,
                )
              else
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      DrawWheel(
                        labels: labels,
                        rotation: _rotation,
                        colors: context.colors.wheelColors,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: DrawSpinButton(
                          label: _isSpinning
                              ? context.l10n.drawSpinning
                              : context.l10n.drawSpin,
                          isSpinning: _isSpinning,
                          onPressed:
                              !canRun || alreadyDrawn || !eligibility.allowed
                              ? null
                              : () => _confirmAndRun(cycle, amountLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              KSpacing.gapXl,
              if (_result != null)
                _WinnerBanner(session: _result!, amountLabel: amountLabel)
              else if (alreadyDrawn)
                _LockedBanner(
                  title: context.l10n.drawAlreadyDone,
                  message: data.beneficiaryOf(cycle.id)!.memberName,
                  action: KButton.secondary(
                    label: context.l10n.beneficiaryTitle,
                    onPressed: () => context.pushReplacement(
                      AppRoutes.tontineBeneficiary(widget.tontineId, cycle.id),
                    ),
                  ),
                )
              else if (!canRun)
                _LockedBanner(
                  title: context.l10n.drawUnavailable,
                  message: context.l10n.drawNoPermission,
                )
              else if (!eligibility.allowed &&
                  eligibility.reason == DrawBlockReason.missingContributions)
                _LockedBanner(
                  title: context.l10n.drawUnavailable,
                  message: context.l10n.drawUnavailableReason(
                    eligibility.missingContributions,
                  ),
                  action: Column(
                    children: <Widget>[
                      KButton.secondary(
                        label: context.l10n.contributionsRecordPayment,
                        icon: Icons.add_card_outlined,
                        onPressed: () => context.push(
                          AppRoutes.tontineCycle(widget.tontineId, cycle.id),
                        ),
                      ),
                      if (canOverride && eligibility.canOverride) ...<Widget>[
                        KSpacing.gapSm,
                        KButton.ghost(
                          label: context.l10n.drawOverrideTitle,
                          icon: Icons.gpp_maybe_outlined,
                          expanded: true,
                          onPressed: () => _forceAndRun(cycle, amountLabel),
                        ),
                      ],
                    ],
                  ),
                )
              else if (!eligibility.allowed)
                _LockedBanner(
                  title: context.l10n.drawUnavailable,
                  message: context.l10n.allocationFullOrderDesc,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DrawStat extends StatelessWidget {
  const _DrawStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: context.text.titleLarge?.copyWith(color: context.colors.brand),
        ),
        const SizedBox(height: KSpacing.xxs),
        Text(
          label,
          style: context.text.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.warningSurface,
        borderRadius: KRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.lock_outline, color: context.colors.warning),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.warning,
            ),
          ),
          if (action != null) ...<Widget>[KSpacing.gapLg, action!],
        ],
      ),
    );
  }
}

/// Rappel du résultat sous la roue, une fois la célébration fermée.
class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.session, required this.amountLabel});

  final DrawSession session;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.successSurface,
        borderRadius: KRadius.card,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.emoji_events, color: context.colors.success),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.winnerName ?? '',
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.success,
                  ),
                ),
                Text(
                  '$amountLabel · ${session.proofReference}',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fenêtre de félicitations affichée après l'arrêt de la roue.
class _DrawCelebrationDialog extends StatelessWidget {
  const _DrawCelebrationDialog({
    required this.session,
    required this.amountLabel,
  });

  final DrawSession session;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(KSpacing.xl),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.85, end: 1),
        duration: KDurations.slow,
        curve: Curves.easeOutBack,
        builder: (BuildContext context, double scale, Widget? child) =>
            Transform.scale(scale: scale, child: child),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('🎉', style: TextStyle(fontSize: 56)),
              KSpacing.gapLg,
              Text(
                context.l10n.drawCongratulations,
                style: context.text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              KSpacing.gapMd,
              Text(
                (session.winnerName ?? '').toUpperCase(),
                style: context.text.titleLarge?.copyWith(
                  color: context.colors.brand,
                ),
                textAlign: TextAlign.center,
              ),
              KSpacing.gapSm,
              Text(
                context.l10n.drawBeneficiaryOf(session.periodLabel),
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              KSpacing.gapLg,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.xl,
                  vertical: KSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: context.colors.accentContainer,
                  borderRadius: KRadius.badge,
                ),
                child: Text(
                  amountLabel,
                  style: context.text.headlineSmall?.copyWith(
                    color: context.colors.accent,
                  ),
                ),
              ),
              KSpacing.gapMd,
              Text(
                '${context.l10n.drawReference} : ${session.proofReference}',
                style: context.text.labelSmall,
              ),
              KSpacing.gapXl,
              KButton(
                label: context.l10n.drawViewResult,
                icon: Icons.card_giftcard_outlined,
                onPressed: () => Navigator.of(
                  context,
                ).pop(_CelebrationAction.viewBeneficiary),
              ),
              KSpacing.gapMd,
              KButton.secondary(
                label: context.l10n.commonContinueLabel,
                onPressed: () =>
                    Navigator.of(context).pop(_CelebrationAction.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
