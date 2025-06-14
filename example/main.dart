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
  final odooClient = OdooClient(odooServerURL, sessionId: session);
  // Catch session changes to store most recent one
  final sessionChangedHandler = storeSesion(cache);
  odooClient.sessionStream.listen(sessionChangedHandler);

  // Network state tracker is needed by Repository
  final netConn = NetworkConnectivity();

  final env = OdooEnvironment(odooClient, odooDbName, cache, netConn);
  // Alternative way to get instanciated user repo
  // final userRepo = odooEnv.add((db) => UserRepository(db));
  env.add(UserRepository(env));
  final userRepo = env.of<UserRepository>();
  var currentUser = userRepo.records[0];
  print('Current user: ${currentUser.name}');

  final userSub = userRepo.recordStream.listen((user) async {
    if (user[0] != currentUser) {
      if (currentUser.isPublic &&
          !user[0].isPublic &&
          user[0].login == 'admin') {
        print('User changed to ${user[0]}');
        currentUser = user[0];
        // we are logged in
        netConn.goOffline();

        print(
            'In offline mode we still can get record: ${userRepo.records[0]}');

        print('scheduling a rpc call to create new user');
        final newUser = await userRepo.create(User.publicUser()
            .copyWith(login: 'newMe', name: 'New Me', lang: 'uk_UA'));

        print('scheduling a rpc call to rename user that was created');
        await userRepo.write(newUser.copyWith(name: 'New Me!'));
        print('going online');
        netConn.goOnline();
      }
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
