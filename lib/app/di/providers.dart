import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/core/network/network_info.dart';
import 'package:kadjane/core/services/attachment_picker.dart';
import 'package:kadjane/core/storage/file_storage.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/core/storage/secure_token_store.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/data/remote/http_api_client.dart';
import 'package:kadjane/data/repositories/mock_audit_repository.dart';
import 'package:kadjane/data/repositories/mock_auth_repository.dart';
import 'package:kadjane/data/repositories/mock_contribution_repository.dart';
import 'package:kadjane/data/repositories/mock_dashboard_repository.dart';
import 'package:kadjane/data/repositories/mock_draw_repository.dart';
import 'package:kadjane/data/repositories/mock_dues_repository.dart';
import 'package:kadjane/data/repositories/mock_member_repository.dart';
import 'package:kadjane/data/repositories/mock_notification_repository.dart';
import 'package:kadjane/data/repositories/mock_organization_repository.dart';
import 'package:kadjane/data/repositories/mock_payout_repository.dart';
import 'package:kadjane/data/repositories/mock_reminder_repository.dart';
import 'package:kadjane/data/repositories/mock_report_repository.dart';
import 'package:kadjane/data/repositories/mock_role_repository.dart';
import 'package:kadjane/data/repositories/mock_tontine_repository.dart';
import 'package:kadjane/data/repositories/mock_treasury_repository.dart';
import 'package:kadjane/data/repositories/rest_auth_repository.dart';
import 'package:kadjane/data/repositories/rest_contribution_repository.dart';
import 'package:kadjane/data/repositories/rest_draw_repository.dart';
import 'package:kadjane/data/repositories/rest_governance_repositories.dart';
import 'package:kadjane/data/repositories/rest_member_repository.dart';
import 'package:kadjane/data/repositories/rest_organization_repository.dart';
import 'package:kadjane/data/repositories/rest_payout_repository.dart';
import 'package:kadjane/data/repositories/rest_support_repositories.dart';
import 'package:kadjane/data/repositories/rest_tontine_repository.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/auth_repository.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';
import 'package:kadjane/domain/repositories/dues_repository.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';
import 'package:kadjane/domain/repositories/notification_repository.dart';
import 'package:kadjane/domain/repositories/organization_repository.dart';
import 'package:kadjane/domain/repositories/payout_repository.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/repositories/report_repository.dart';
import 'package:kadjane/domain/repositories/role_repository.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/domain/repositories/treasury_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';
import 'package:kadjane/domain/services/permission_service.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Injection de dépendances de l'application.
///
/// Chaque repository existe en deux implémentations — mock et REST — choisies
/// ici selon `AppConfig.useMockData`. Aucun écran ne référence une
/// implémentation concrète : basculer l'application sur le backend ne demande
/// donc aucune modification de la couche présentation.

final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => AppConfig.current,
);

/// Source de données courante : mock local ou backend REST.
final Provider<bool> useMockDataProvider = Provider<bool>(
  (Ref ref) => ref.watch(appConfigProvider).useMockData,
);

/// Stockage clé/valeur : surchargé au démarrage avec `SharedPreferences`.
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (Ref ref) => InMemoryKeyValueStore(),
);

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => SecureTokenStore(),
);

final Provider<NetworkInfo> networkInfoProvider = Provider<NetworkInfo>(
  (Ref ref) => ConnectivityNetworkInfo(),
);

/// Client HTTP du backend : jeton d'accès, renouvellement de session et
/// conversion des codes HTTP en exceptions métier.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  if (ref.watch(useMockDataProvider)) {
    return const NotConfiguredApiClient();
  }
  final HttpApiClient client = HttpApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
  );
  ref.onDispose(client.close);
  return client;
});

/// Base de données mock partagée par tous les repositories mock.
final Provider<MockDatabase> mockDatabaseProvider = Provider<MockDatabase>(
  (Ref ref) => MockDatabase(),
);

/// Sélection d'un justificatif (photo ou galerie).
final Provider<AttachmentPicker> attachmentPickerProvider =
    Provider<AttachmentPicker>((Ref ref) => ImageAttachmentPicker());

final Provider<FileStorage> fileStorageProvider = Provider<FileStorage>((
  Ref ref,
) {
  final MockDatabase db = ref.watch(mockDatabaseProvider);
  // TODO(api): brancher `S3FileStorage` (URL pré-signées) en mode REST.
  return LocalFileStorage(() => db.nextId('att'));
});

// --- Services métier --------------------------------------------------------

final Provider<PermissionService> permissionServiceProvider =
    Provider<PermissionService>((Ref ref) => const PermissionService());

final Provider<TontineRulesService> tontineRulesProvider =
    Provider<TontineRulesService>((Ref ref) => const TontineRulesService());

final Provider<DunningService> dunningServiceProvider =
    Provider<DunningService>((Ref ref) => const DunningService());

// --- Repositories -----------------------------------------------------------

final Provider<AuditRepository> auditRepositoryProvider =
    Provider<AuditRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockAuditRepository(ref.watch(mockDatabaseProvider))
          : RestAuditRepository(ref.watch(apiClientProvider)),
    );

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockAuthRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(tokenStoreProvider),
              ref.watch(keyValueStoreProvider),
            )
          : RestAuthRepository(
              ref.watch(apiClientProvider),
              ref.watch(tokenStoreProvider),
              ref.watch(keyValueStoreProvider),
            ),
    );

final Provider<OrganizationRepository> organizationRepositoryProvider =
    Provider<OrganizationRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockOrganizationRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
            )
          : RestOrganizationRepository(ref.watch(apiClientProvider)),
    );

final Provider<MemberRepository> memberRepositoryProvider =
    Provider<MemberRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockMemberRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
            )
          : RestMemberRepository(ref.watch(apiClientProvider)),
    );

final Provider<TontineRepository> tontineRepositoryProvider =
    Provider<TontineRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockTontineRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
            )
          : RestTontineRepository(ref.watch(apiClientProvider)),
    );

final Provider<ContributionRepository> contributionRepositoryProvider =
    Provider<ContributionRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockContributionRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
            )
          : RestContributionRepository(ref.watch(apiClientProvider)),
    );

final Provider<DrawRepository> drawRepositoryProvider =
    Provider<DrawRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockDrawRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
            )
          : RestDrawRepository(ref.watch(apiClientProvider)),
    );

final Provider<PayoutRepository> payoutRepositoryProvider =
    Provider<PayoutRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockPayoutRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
            )
          : RestPayoutRepository(ref.watch(apiClientProvider)),
    );

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockNotificationRepository(ref.watch(mockDatabaseProvider))
          : RestNotificationRepository(ref.watch(apiClientProvider)),
    );

final Provider<DuesRepository> duesRepositoryProvider =
    Provider<DuesRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockDuesRepository(ref.watch(mockDatabaseProvider))
          : RestDuesRepository(ref.watch(apiClientProvider)),
    );

final Provider<TreasuryRepository> treasuryRepositoryProvider =
    Provider<TreasuryRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockTreasuryRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
            )
          : RestTreasuryRepository(ref.watch(apiClientProvider)),
    );

final Provider<DashboardRepository> dashboardRepositoryProvider =
    Provider<DashboardRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockDashboardRepository(ref.watch(mockDatabaseProvider))
          : RestDashboardRepository(ref.watch(apiClientProvider)),
    );

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockReportRepository(ref.watch(mockDatabaseProvider))
          : RestReportRepository(ref.watch(apiClientProvider)),
    );

final Provider<RoleRepository> roleRepositoryProvider =
    Provider<RoleRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockRoleRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
              ref.watch(permissionServiceProvider),
            )
          : RestRoleRepository(ref.watch(apiClientProvider)),
    );

final Provider<ReminderRepository> reminderRepositoryProvider =
    Provider<ReminderRepository>(
      (Ref ref) => ref.watch(useMockDataProvider)
          ? MockReminderRepository(
              ref.watch(mockDatabaseProvider),
              ref.watch(auditRepositoryProvider),
              ref.watch(dunningServiceProvider),
            )
          : RestReminderRepository(ref.watch(apiClientProvider)),
    );
