import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/repositories/auth_repository.dart';
import 'package:kadjane/features/notifications/presentation/providers/push_providers.dart';

/// Session de l'utilisateur connecté.
///
/// `null` signifie « non authentifié ». L'état de chargement initial sert à
/// afficher le splash le temps de restaurer la session sécurisée.
class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() => _repository.restoreSession();

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    state = const AsyncValue<AuthSession?>.loading();
    state = await AsyncValue.guard<AuthSession?>(
      () => _repository.signIn(identifier: identifier, password: password),
    );
  }

  Future<void> register(RegisterDraft draft) async {
    state = const AsyncValue<AuthSession?>.loading();
    state = await AsyncValue.guard<AuthSession?>(
      () => _repository.register(draft),
    );
  }

  Future<void> signOut() async {
    // Avant la purge de la session : détacher l'appareil demande un appel
    // authentifié, et sans lui le téléphone continuerait de recevoir les
    // relances de l'utilisateur qui part.
    await ref.read(pushRegistrarProvider).detach();
    await _repository.signOut();
    state = const AsyncValue<AuthSession?>.data(null);
  }

  Future<void> updateProfile(User user) async {
    final AuthSession? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final User updated = await _repository.updateProfile(user);
    state = AsyncValue<AuthSession?>.data(current.copyWith(user: updated));
  }

  /// Renouvelle la session lorsque le jeton approche de son expiration.
  Future<void> refresh() async {
    state = await AsyncValue.guard<AuthSession?>(
      () => _repository.refreshSession(),
    );
  }
}

final AsyncNotifierProvider<AuthController, AuthSession?>
authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession?>(
  AuthController.new,
);

/// Utilisateur connecté (ou `null`).
final Provider<User?> currentUserProvider = Provider<User?>(
  (Ref ref) => ref.watch(authControllerProvider).valueOrNull?.user,
);

final Provider<bool> isAuthenticatedProvider = Provider<bool>(
  (Ref ref) => ref.watch(authControllerProvider).valueOrNull != null,
);
