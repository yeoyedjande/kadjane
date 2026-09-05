import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';

class DuesEntryDto {
  const DuesEntryDto._();

  static DuesEntry fromJson(JsonMap json) {
    // Le serveur imbrique le plan quand il le connaît ; sur `/me/dues` le nom
    // n'est pas toujours joint, d'où le repli sur une chaîne vide.
    final JsonMap? plan = Json.objectOrNull(json, 'plan');
    final JsonMap? member = Json.objectOrNull(json, 'member');
    final JsonMap? user = member == null
        ? null
        : Json.objectOrNull(member, 'user');
    return DuesEntry(
      id: Json.string(json, 'id'),
      planId: Json.stringOr(json, 'planId'),
      planName: plan == null ? '' : Json.stringOr(plan, 'name'),
      memberId: Json.stringOr(json, 'memberId'),
      memberName: user == null
          ? ''
          : '${Json.stringOr(user, 'firstName')} ${Json.stringOr(user, 'lastName')}'
                .trim(),
      sequenceNumber: Json.integer(json, 'sequenceNumber', 1),
      periodLabel: Json.stringOr(json, 'periodLabel'),
      dueDate: Json.dateOrNull(json, 'dueDate') ?? DateTime.now(),
      expectedAmount: Json.amount(json, 'expectedAmount'),
      paidAmount: Json.amount(json, 'paidAmount'),
      status: DuesStatus.fromCode(Json.stringOr(json, 'status', 'pending')),
    );
  }
}

class DuesPlanDto {
  const DuesPlanDto._();

  static DuesPlan fromJson(JsonMap json) {
    final JsonMap? summary = Json.objectOrNull(json, 'summary');
    return DuesPlan(
      id: Json.string(json, 'id'),
      organizationId: Json.stringOr(json, 'organizationId'),
      name: Json.stringOr(json, 'name'),
      amount: Json.amount(json, 'amount'),
      currency: Json.stringOr(json, 'currency', 'XOF'),
      frequency: TontineFrequency.fromCode(
        Json.stringOr(json, 'frequency', 'monthly'),
      ),
      customPeriodDays: json['customPeriodDays'] == null
          ? null
          : Json.integer(json, 'customPeriodDays'),
      dueDay: Json.integer(json, 'dueDay', 5),
      startDate: Json.dateOrNull(json, 'startDate'),
      status: DuesPlanStatus.fromCode(Json.stringOr(json, 'status', 'active')),
      description: Json.stringOrNull(json, 'description'),
      unpaidCount: summary == null ? 0 : Json.integer(summary, 'unpaidCount'),
      collectedTotal: summary == null
          ? 0
          : Json.amount(summary, 'collectedTotal'),
      outstandingTotal: summary == null
          ? 0
          : Json.amount(summary, 'outstandingTotal'),
    );
  }

  /// Corps de création. `startDate` est envoyée en date seule : le serveur
  /// attend un `date`, pas un instant.
  static JsonMap createBody(DuesPlanDraft draft) => <String, dynamic>{
    'name': draft.name,
    'amount': draft.amount,
    'currency': draft.currency,
    'frequency': draft.frequency.code,
    'dueDay': draft.dueDay,
    if (draft.frequency == TontineFrequency.custom &&
        draft.customPeriodDays != null)
      'customPeriodDays': draft.customPeriodDays,
    if (draft.startDate != null) 'startDate': _day(draft.startDate!),
    if (draft.description != null && draft.description!.isNotEmpty)
      'description': draft.description,
  };

  /// Corps de mise à jour : seuls les champs fournis sont transmis, pour ne pas
  /// écraser par `null` ce que l'appelant n'a pas voulu changer.
  static JsonMap updateBody({
    String? name,
    double? amount,
    String? description,
    int? dueDay,
    DuesPlanStatus? status,
  }) => <String, dynamic>{
    'name': ?name,
    'amount': ?amount,
    'description': ?description,
    'dueDay': ?dueDay,
    'status': ?status?.code,
  };

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
