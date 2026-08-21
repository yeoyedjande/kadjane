import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Détection de connectivité, utilisée pour l'état hors ligne des écrans.
abstract interface class NetworkInfo {
  Future<bool> get isConnected;

  Stream<bool> get onConnectivityChanged;
}

class ConnectivityNetworkInfo implements NetworkInfo {
  ConnectivityNetworkInfo([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      return _isOnline(results);
    } on Exception {
      // En cas d'échec de la plateforme, on suppose l'appareil connecté afin de
      // ne pas bloquer l'utilisateur.
      return true;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}

/// Implémentation de test : toujours connectée par défaut.
class AlwaysOnlineNetworkInfo implements NetworkInfo {
  AlwaysOnlineNetworkInfo({this.connected = true});

  final bool connected;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream<bool>.value(connected);
}
