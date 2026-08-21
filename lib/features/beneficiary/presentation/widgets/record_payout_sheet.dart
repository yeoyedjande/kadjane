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
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/payout_repository.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Enregistrement du versement de la cagnotte au bénéficiaire.
class RecordPayoutSheet extends ConsumerStatefulWidget {
  const RecordPayoutSheet({
    required this.beneficiary,
    required this.tontineId,
    super.key,
  });

  final Beneficiary beneficiary;
  final String tontineId;

  @override
  ConsumerState<RecordPayoutSheet> createState() => _RecordPayoutSheetState();
}

class _RecordPayoutSheetState extends ConsumerState<RecordPayoutSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.beneficiary.amount.toStringAsFixed(0),
  );
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _comment = TextEditingController();

  PaymentMethod _method = PaymentMethod.wave;
  DateTime _sentAt = DateTime.now();
  Attachment? _attachment;
  bool _isSaving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final LocalFile? file = await ref
        .read(attachmentPickerProvider)
        .pickFromGallery();
    if (file == null) {
      return;
    }
    final Attachment attachment = await ref
        .read(fileStorageProvider)
        .upload(file);
    setState(() => _attachment = attachment);
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
          .read(payoutRepositoryProvider)
          .record(
            actorMemberId: actor.id,
            draft: PayoutDraft(
              beneficiaryId: widget.beneficiary.id,
              amount: amount,
              method: _method,
              sentAt: _sentAt,
              reference: _reference.text.trim().isEmpty
                  ? null
                  : _reference.text.trim(),
              comment: _comment.text.trim().isEmpty
                  ? null
                  : _comment.text.trim(),
              attachmentId: _attachment?.id,
            ),
          );
      ref.invalidate(tontineDetailProvider(widget.tontineId));
      refreshOrganizationData(ref);
      if (mounted) {
        Navigator.of(context).pop(true);
        context.showMessage(context.l10n.beneficiaryPayoutRecorded);
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
              context.l10n.beneficiaryRecordPayout,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: KSpacing.xs),
            Text(widget.beneficiary.memberName, style: context.text.bodyMedium),
            KSpacing.gapXl,
            KTextField(
              label: context.l10n.beneficiaryAmountSent,
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
              value: _sentAt,
              onChanged: (DateTime value) => setState(() => _sentAt = value),
            ),
            KSpacing.gapLg,
            KTextField(
              label:
                  '${context.l10n.commonReference} (${context.l10n.commonOptional})',
              controller: _reference,
            ),
            KSpacing.gapLg,
            KTextField(
              label:
                  '${context.l10n.commonComment} (${context.l10n.commonOptional})',
              controller: _comment,
              maxLines: 2,
            ),
            KSpacing.gapLg,
            KButton.secondary(
              label: _attachment == null
                  ? context.l10n.contributionsAddProof
                  : _attachment!.fileName,
              icon: Icons.attach_file,
              size: KButtonSize.small,
              onPressed: _pickProof,
            ),
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
