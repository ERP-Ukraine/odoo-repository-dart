import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:pedantic/pedantic.dart';

import 'kv_store.dart';
import 'network_connection_state.dart';
import 'odoo_repository.dart';
import 'odoo_rpc_call.dart';

class OdooEnvironment {
  /// Odoo RPC client
  late OdooClient orpc;

  /// Database name to connect to.
  late final String dbName;

  // Key-value cache client
  late OdooKv cache;

  /// Tracks current network state: online or offline
  late NetConnState netConnectivity;

  /// Holds a list of Odoo Repositories
  final _registry = <OdooRepository>[];

  OdooEnvironment(this.orpc, this.dbName, this.cache, this.netConnectivity) {
    orpc.loginStream.listen(loginStateChanged);
    netConnectivity.onNetConnChanged.listen(onNetworkConnChanged);
    // check if our session is valid for database
    if (orpc.sessionId != null && orpc.sessionId!.dbName != dbName) {
      orpc.destroySession();
    }
  }

  bool get isAuthenticated =>
      orpc.sessionId != null && orpc.sessionId?.id != '';

  /// Adds instance of Odoo Repository to registry
  T add<T extends OdooRepository>(T repo) {
    if (!_registry.contains(repo)) {
      _registry.add(repo);
    }
    return repo;
  }

  /// Returns Odoo Repository of given type.
  /// Example:  [of<UserRepository>()]
  T of<T extends OdooRepository>() {
    for (var repo in _registry) {
      if (repo is T) {
        return repo;
      }
    }
    throw Exception('Repo of type $T not found');
  }
  // TODO: move processCallQueue logic from model to env.
  // Make it syncrhonous comparing to [create()] and other methods that
  // are depending on [Record.id]  as it may change after sync.
  // In any moment of time either sync, that replaces fake id to real id
  // or [create()], [write()], etc call should be executed.
  // Add [externalId] field to Record. It must remain unchanged.
  // It must be fetched with separate call.
  Future<void> _processCallQueue() async {
    for (var repo in _registry) {
      await repo.processCallQueue();
    }
  }

  /// Puts [rpcCall] to calls queue that will be processed when online
  Future<void> queueRequest(OdooRpcCall rpcCall) async {
    await cache.put(rpcCall.cacheKey, rpcCall);
    if (await netConnectivity.checkNetConn() == netConnState.online) {
      unawaited(_processCallQueue());
    }
  }

  /// Called when going online/offline
  void onNetworkConnChanged(netConnState netState) {
    if (netState == netConnState.online) {
      _processCallQueue();
    }
  }

  Future<void> loginStateChanged(OdooLoginEvent event) async {
    if (event == OdooLoginEvent.loggedIn) {
      for (var repo in _registry) {
        // It will call getRecords at the end
        await repo.processCallQueue();
      }
    }
    if (event == OdooLoginEvent.loggedOut) {
      for (var repo in _registry) {
        // send empty list of records without deleting them from cache
        repo.clearRecords();
      }
    }
  }
}
