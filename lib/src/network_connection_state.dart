/// Describes current network connection state
enum netConnState { online, offline }

/// Provides interface to get current network connection state
/// and listen to events of going online/offline.
abstract class NetConnState {
  Future<netConnState> checkNetConn();

  Stream<netConnState> get onNetConnChanged;
}
