import 'dart:async';
import 'package:odoo_repository/odoo_repository.dart'
    show netConnState, NetConnState;

class NetworkConnectivity implements NetConnState {
  static NetworkConnectivity? _singleton;

  factory NetworkConnectivity() {
    _singleton ??= NetworkConnectivity._();
    return _singleton!;
  }

  late bool isOnline;
  late StreamController<netConnState> recordStreamController;

  NetworkConnectivity._() {
    isOnline = true;
    recordStreamController = StreamController<netConnState>.broadcast(
        onListen: () {}, onCancel: () {}, sync: true);
  }

  void goOnline() {
    isOnline = true;
    recordStreamController.add(netConnState.online);
  }

  void goOffline() {
    isOnline = false;
    recordStreamController.add(netConnState.offline);
  }

  @override
  Future<netConnState> checkNetConn() async {
    return isOnline ? netConnState.online : netConnState.offline;
  }

  @override
  Stream<netConnState> get onNetConnChanged {
    return recordStreamController.stream;
  }
}
