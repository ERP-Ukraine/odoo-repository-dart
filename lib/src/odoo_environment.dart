import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:pedantic/pedantic.dart';

import 'kv_store.dart';
import 'network_connection_state.dart';
import 'odoo_database.dart';
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

  /// Holds connection info
  late final OdooDatabase _database;

  /// Holds a list of Odoo Repositories
  final _registry = <OdooRepository>[];

  OdooEnvironment(this.orpc, this.dbName, this.cache, this.netConnectivity) {
    orpc.loginStream.listen(loginStateChanged);
    netConnectivity.onNetConnChanged.listen(onNetworkConnChanged);
    _database = OdooDatabase(orpc, dbName, cache, queueRequest);
    // check if our session is valid for database
    if (orpc.sessionId != null && orpc.sessionId!.dbName != dbName) {
      orpc.destroySession();
    }
  }

  OdooDatabase get database => _database;

  bool get isAuthenticated =>
      orpc.sessionId != null && orpc.sessionId?.id != '';

  /// Creates instance of Odoo Repository with given constructor and adds instance to registry
  T add<T extends OdooRepository>(T Function(OdooDatabase db) repoCreator) {
    var repo = repoCreator(database);
    if (!_registry.contains(repo)) {
      _registry.add(repo);
    }
    return repo;
  }

  /// Access Odoo Repository of given type like [env<UserRepository>()]
  T env<T extends OdooRepository>() {
    for (var repo in _registry) {
      if (repo is T) {
        return repo;
      }
    }
    throw Exception('Repo of type $T not found');
  }

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
