import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/services/dunning_service.dart';

/// Identifie un cycle pour les providers de relance.
class CycleRef {
  const CycleRef({required this.tontineId, required this.cycleId});

  final String tontineId;
  final String cycleId;

  @override
  bool operator ==(Object other) =>
      other is CycleRef &&
      other.tontineId == tontineId &&
      other.cycleId == cycleId;

  @override
  int get hashCode => Object.hash(tontineId, cycleId);
}

/// Membres à relancer dans toute l'organisation active.
final AutoDisposeFutureProvider<List<DunningTarget>>
organizationDunningProvider = FutureProvider.autoDispose<List<DunningTarget>>((
  Ref ref,
) async {
  final String? organizationId = await ref.watch(
    activeOrganizationIdProvider.future,
  );
  if (organizationId == null) {
    return const <DunningTarget>[];
  }
  return ref
      .watch(reminderRepositoryProvider)
      .targetsForOrganization(organizationId);
});

/// Membres à relancer pour un cycle précis.
final AutoDisposeFutureProviderFamily<List<DunningTarget>, CycleRef>
cycleDunningProvider = FutureProvider.autoDispose
    .family<List<DunningTarget>, CycleRef>(
      (Ref ref, CycleRef cycle) => ref
          .watch(reminderRepositoryProvider)
          .targetsForCycle(tontineId: cycle.tontineId, cycleId: cycle.cycleId),
    );

/// Campagnes de relance de l'organisation active.
final AutoDisposeFutureProvider<List<ReminderCampaign>>
reminderCampaignsProvider = FutureProvider.autoDispose<List<ReminderCampaign>>((
  Ref ref,
) async {
  final String? organizationId = await ref.watch(
    activeOrganizationIdProvider.future,
  );
  if (organizationId == null) {
    return const <ReminderCampaign>[];
  }
  return ref.watch(reminderRepositoryProvider).campaignsOf(organizationId);
});

/// Relances reçues par le membre connecté (son espace personnel).
final AutoDisposeFutureProvider<List<Reminder>> myRemindersProvider =
    FutureProvider.autoDispose<List<Reminder>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      final OrganizationMember? membership = await ref.watch(
        currentMembershipProvider.future,
      );
      if (organizationId == null || membership == null) {
        return const <Reminder>[];
      }
      return ref
          .watch(reminderRepositoryProvider)
          .forMember(organizationId: organizationId, memberId: membership.id);
    });

/// Relances non lues du membre connecté.
final AutoDisposeProvider<List<Reminder>> myUnreadRemindersProvider =
    Provider.autoDispose<List<Reminder>>((Ref ref) {
      final List<Reminder> reminders =
          ref.watch(myRemindersProvider).valueOrNull ?? const <Reminder>[];
      return reminders
          .where((Reminder r) => !r.isRead && r.isDelivered)
          .toList(growable: false);
    });
