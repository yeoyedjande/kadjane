import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/storage/file_storage.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/attachment.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/features/contributions/presentation/providers/contribution_providers.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Formulaire d'enregistrement d'un paiement (trésorier).
class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({
    required this.tontineId,
    required this.cycleId,
    required this.memberId,
    required this.memberName,
    required this.expectedAmount,
    super.key,
  });

  final String tontineId;
  final String cycleId;
  final String memberId;
  final String memberName;
  final double expectedAmount;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.expectedAmount.toStringAsFixed(0),
  );
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _comment = TextEditingController();

  PaymentMethod _method = PaymentMethod.wave;
  ContributionStatus _status = ContributionStatus.confirmed;
  DateTime _paidAt = DateTime.now();
  Attachment? _attachment;
  bool _isSaving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickProof({required bool fromCamera}) async {
    try {
      final LocalFile? file = fromCamera
          ? await ref.read(attachmentPickerProvider).pickFromCamera()
          : await ref.read(attachmentPickerProvider).pickFromGallery();
      if (file == null) {
        return;
      }
      final Attachment attachment = await ref
          .read(fileStorageProvider)
          .upload(file);
      setState(() => _attachment = attachment);
    } on Object {
      if (mounted) {
        context.showMessage(context.l10n.commonErrorGeneric, isError: true);
      }
    }
  }

  Future<void> _submit() async {
    final double? amount = Validators.parseAmount(_amount.text);
    if (amount == null || amount <= 0) {
      context.showMessage(context.l10n.commonRequiredField, isError: true);
      return;
    }
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .record(
            actorMemberId: actor.id,
            draft: ContributionDraft(
              tontineId: widget.tontineId,
              cycleId: widget.cycleId,
              memberId: widget.memberId,
              amount: amount,
              method: _method,
              status: _status,
              paidAt: _paidAt,
              reference: _reference.text.trim().isEmpty
                  ? null
                  : _reference.text.trim(),
              comment: _comment.text.trim().isEmpty
                  ? null
                  : _comment.text.trim(),
              attachmentId: _attachment?.id,
            ),
          );
      ref
        ..invalidate(cycleSlotsProvider(widget.cycleId))
        ..invalidate(cycleContributionsProvider(widget.cycleId))
        ..invalidate(tontineDetailProvider(widget.tontineId));
      refreshOrganizationData(ref);
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showMessage(context.l10n.contributionsRecorded);
      }
    } on Object catch (error) {
      if (mounted) {
        context.showMessage(
          ErrorMapper.message(context.l10n, error),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.contributionsRecordPayment,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: KSpacing.xs),
            Text(widget.memberName, style: context.text.bodyMedium),
            KSpacing.gapXl,
            KTextField(
              label: context.l10n.commonAmount,
              controller: _amount,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments_outlined,
            ),
            KSpacing.gapLg,
            KDropdownField<PaymentMethod>(
              label: context.l10n.contributionsPaymentMethod,
              value: _method,
              items: PaymentMethod.values,
              itemLabel: (PaymentMethod method) =>
                  Labels.paymentMethod(context.l10n, method),
              itemIcon: Labels.paymentIcon,
              onChanged: (PaymentMethod? value) =>
                  setState(() => _method = value ?? PaymentMethod.wave),
            ),
            KSpacing.gapLg,
            KDateField(
              label: context.l10n.commonDate,
              value: _paidAt,
              onChanged: (DateTime value) => setState(() => _paidAt = value),
            ),
            KSpacing.gapLg,
            KTextField(
              label:
                  '${context.l10n.commonReference} (${context.l10n.commonOptional})',
              controller: _reference,
            ),
            KSpacing.gapLg,
            KDropdownField<ContributionStatus>(
              label: context.l10n.commonStatus,
              value: _status,
              items: const <ContributionStatus>[
                ContributionStatus.confirmed,
                ContributionStatus.pending,
              ],
              itemLabel: (ContributionStatus status) =>
                  Labels.contributionStatus(context.l10n, status),
              onChanged: (ContributionStatus? value) => setState(
                () => _status = value ?? ContributionStatus.confirmed,
              ),
            ),
            KSpacing.gapLg,
            KTextField(
              label:
                  '${context.l10n.commonComment} (${context.l10n.commonOptional})',
              controller: _comment,
              maxLines: 2,
            ),
            KSpacing.gapLg,
            Text(
              context.l10n.contributionsProof,
              style: context.text.labelMedium,
            ),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: KButton.secondary(
                    label: context.l10n.contributionsTakePhoto,
                    icon: Icons.photo_camera_outlined,
                    size: KButtonSize.small,
                    onPressed: () => _pickProof(fromCamera: true),
                  ),
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: KButton.secondary(
                    label: context.l10n.contributionsChooseImage,
                    icon: Icons.image_outlined,
                    size: KButtonSize.small,
                    onPressed: () => _pickProof(fromCamera: false),
                  ),
                ),
              ],
            ),
            if (_attachment != null) ...<Widget>[
              const SizedBox(height: KSpacing.sm),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.attachment,
                    size: KSizes.iconSm,
                    color: context.colors.success,
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(
                      _attachment!.fileName,
                      style: context.text.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            KSpacing.gapXl,
            KButton(
              label: context.l10n.commonSave,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
