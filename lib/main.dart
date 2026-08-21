import 'package:kadjane/bootstrap.dart';
import 'package:kadjane/core/config/app_config.dart';

/// Point d'entrée par défaut (environnement de développement).
///
/// Autres environnements :
///   flutter run --dart-define=KADJANE_ENV=staging
///   flutter build apk --dart-define=KADJANE_ENV=production
Future<void> main() => bootstrap(AppConfig.fromDartDefine());
