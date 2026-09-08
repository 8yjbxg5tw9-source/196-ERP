import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity abstraction used by repositories instead of platform APIs.
abstract interface class NetworkInfo {
  Future<bool> get isConnected;

  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final List<ConnectivityResult> results =
        await _connectivity.checkConnectivity();
    return results.any(
      (ConnectivityResult result) => result != ConnectivityResult.none,
    );
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}
