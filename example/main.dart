import 'dart:io';

import 'package:odoo_repository/odoo_repository.dart' show OdooEnvironment;
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:user_repository/user_repository.dart';

import 'config.dart';
import 'net_conn_impl.dart';
import 'odoo_kv_hive_impl.dart';

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

  final odooEnv = OdooEnvironment(odooClient, odooDbName, cache, netConn);
  // Alternative way to get instanciated user repo
  // final userRepo = odooEnv.add((db) => UserRepository(db));
  odooEnv.add((db) => UserRepository(db));
  final userRepo = odooEnv.env<UserRepository>();
  var currentUser = userRepo.records[0];
  print('Current user: ${currentUser.name}');

  final userSub = userRepo.recordStream.listen((user) async {
    if (user[0] != currentUser) {
      print('User changed to ${user[0]}');
      if (currentUser.isPublic && !user[0].isPublic) {
        // we are logged in
        netConn.goOffline();

        print(
            'In offline mode we still can get record: ${userRepo.records[0]}');

        print('scheduling a rpc call to change user name');
        await userRepo.execute(recordId: user[0].id, method: 'write',
            // we need to pass record id as first argument
            // because write() is not @api.model
            args: [
              user[0].id
            ], kwargs: <String, dynamic>{
          'vals': <String, dynamic>{'name': 'Invoicy Girl'}
        });
        print('going online');
        netConn.goOnline();
      }
      currentUser = user[0];
    }
  })
    ..onError((error) => print('User repo error: $error'));

  ProcessSignal.sigint.watch().listen((signal) async {
    print('Exiting...');
    userRepo.logOutUser();
    await userSub.cancel();
    exit(0);
  });

  // Authentication will push new users list to userRepo.recordStream
  await userRepo.authenticateUser(login: 'admin', password: 'admin');
  print('Hit CTRL+c to exit');
  // we need to wait unit async calls will finish
  await Future.delayed(Duration(seconds: 100));
}
