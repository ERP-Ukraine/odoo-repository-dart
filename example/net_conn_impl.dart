import 'package:odoo_repository/odoo_repository.dart'
    show netConnState, NetConnState;

/// For purpose of this demo we'll implement network
/// state checker that always returns online state
class NetworkConnectivity implements NetConnState {
  static NetworkConnectivity? _singleton;

  factory NetworkConnectivity() {
    _singleton ??= NetworkConnectivity._();
    return _singleton!;
  }

  NetworkConnectivity._();

  @override
  Future<netConnState> checkNetConn() async {
    return netConnState.online;
  }

  @override
  Stream<netConnState> get onNetConnChanged async* {
    yield netConnState.online;
  }
}
