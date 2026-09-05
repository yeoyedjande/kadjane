import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/features/activity/presentation/providers/activity_providers.dart';
import 'package:kadjane/features/contributions/presentation/providers/contribution_providers.dart';
import 'package:kadjane/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:kadjane/features/dues/presentation/providers/dues_providers.dart';
import 'package:kadjane/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kadjane/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:kadjane/features/tontines/presentation/providers/tontine_providers.dart';

/// Invalide les données dépendantes de l'organisation après une écriture.
///
/// Les mutations passent toujours par un repository ; on rafraîchit ensuite
/// les lectures d'un seul endroit pour éviter les écrans désynchronisés.
void refreshOrganizationData(WidgetRef ref) {
  ref
    ..invalidate(dashboardProvider)
    ..invalidate(tontineSummariesProvider)
    ..invalidate(myContributionsProvider)
    ..invalidate(activityLogsProvider)
    ..invalidate(notificationsProvider)
    ..invalidate(organizationDunningProvider)
    ..invalidate(myRemindersProvider)
    ..invalidate(duesPlansProvider)
    ..invalidate(duesEntriesProvider)
    ..invalidate(myDuesProvider);
}
