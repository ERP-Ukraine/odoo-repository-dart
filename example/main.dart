import 'dart:io';

import 'package:odoo_rpc/odoo_rpc.dart';

import 'package:user_repository/user_repository.dart';
import 'config.dart';
import 'odoo_kv_hive_impl.dart';
import 'net_conn_impl.dart';

void main() async {
  // Init cache storage implemented with Hive
  final cache = OdooKvHive();
  await cache.init();

  // Try to recover session from storage
  OdooSession? session = cache.get(cacheSessionKey, defaultValue: null);
  // If session is still valid we will be logged in
  final odooClient = OdooClient(odooServerURL, session);
  // Catch session changes to store most recent one
  final sessionChangedHandler = storeSesion(cache);
  odooClient.sessionStream.listen(sessionChangedHandler);

  // Network state tracker is needed by Repository
  final netConn = NetworkConnectivity();

  final userRepo = UserRepository(odooClient, odooDbName, cache, netConn);
  var currentUser = userRepo.records[0];
  print('Current user: ${currentUser.name}');

  final _ = userRepo.recordStream.listen((user) {
    if (user[0] != currentUser) {
      currentUser = user[0];
      print('User changed to ${user[0]}');
    }
  })
    ..onError((error) => print('User repo error: $error'));

  // Authentication will push new users list to userRepo.recordStream
  await userRepo.authenticateUser(login: 'admin', password: 'admin');
  if (!currentUser.isPublic) {
    // it will push public user to a stream
    userRepo.logOutUser();
  }
}
