import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';

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
      name: Json.stringOr(json, 'name'),
      amount: Json.amount(json, 'amount'),
      frequency: Json.stringOr(json, 'frequency', 'monthly'),
      dueDay: Json.integer(json, 'dueDay', 5),
      status: Json.stringOr(json, 'status', 'active'),
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
}
