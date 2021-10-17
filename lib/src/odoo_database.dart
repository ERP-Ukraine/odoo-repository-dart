import 'package:equatable/equatable.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import 'kv_store.dart';
import 'odoo_rpc_call.dart';

/// Represents info needed for Repository models
class OdooDatabase extends Equatable {
  /// Odoo RPC client
  final OdooClient orpc;

  /// Database name to connect to.
  final String dbName;

  // Key-value cache client
  final OdooKv cache;

  final Future<void> Function(OdooRpcCall) queueRequest;

  const OdooDatabase(this.orpc, this.dbName, this.cache, this.queueRequest);

  // Equatable stuff to compare records
  @override
  List<Object> get props => [orpc.baseURL, orpc.sessionId?.userId ?? 0, dbName];
}
