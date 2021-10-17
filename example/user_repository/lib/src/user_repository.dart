import 'dart:async';

import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:pedantic/pedantic.dart';

import 'user_record.dart';

/// User repository interacts with local cache and remote Odoo instance
/// to provide access to User's data.
class UserRepository extends OdooRepository<User> {
  @override
  final String modelName = 'res.users';

  // We need only one record of our user
  @override
  int remoteRecordsCount = 1;

  /// Instantiates [UserRepository] with given [OdooClient].
  UserRepository(OdooEnvironment odoo) : super(odoo) {
    // track if session is destroyed.
    // Any ORM call may fail due to expired session.
    // We need to kill user in that case.
    env.orpc.sessionStream.listen(sessionChanged);
  }

  Future<void> authenticateUser(
      {required String login, required String password}) async {
    try {
      logger.d('Authenticating user `$login`');
      await env.orpc.authenticate(env.dbName, login, password);
      unawaited(fetchRecords());
    } on OdooException {
      if (recordStreamActive) {
        recordStreamController.addError('Unable to Login');
      }
    } catch (e) {
      if (recordStreamActive) {
        recordStreamController.addError('Network Error');
      }
    }
  }

  void logOutUser() {
    logger.d('Logging out user `${latestRecords[0].login}`');
    clearCaches();
    env.orpc.destroySession().then((value) => clearRecords());
  }

  void sessionChanged(OdooSession sessionId) {
    if (sessionId.id == '') {
      logOutUser();
    }
  }

  @override
  void clearRecords() {
    // We need to send public user instead of empty list as usual
    latestRecords = [User.publicUser()];
    if (recordStreamActive) {
      recordStreamController.add(latestRecords);
    }
  }

  @override
  User createRecordFromJson(Map<String, dynamic> json) {
    return User.fromJson(json);
  }

  @override
  List<User> get records {
    if (!isAuthenticated) {
      latestRecords = [User.publicUser()];
      return latestRecords;
    }
    var cachedUsers = super.records;
    if (cachedUsers.isEmpty) {
      cachedUsers.add(User.publicUser());
      latestRecords = cachedUsers;
    }
    return cachedUsers;
  }

  // Need to override searchRead because we are computing image url
  // and constructing domain based on latest used id found in session.
  @override
  Future<List<dynamic>> searchRead() async {
    var publicUserJson = User.publicUser().toJson();
    if (!isAuthenticated) {
      return [publicUserJson];
    }
    try {
      final userId = env.orpc.sessionId!.userId;
      var res = await env.orpc.callKw({
        'model': modelName,
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'context': {'bin_size': true},
          'domain': [
            ['id', '=', userId]
          ],
          'fields': User.oFields,
          'limit': limit,
        },
      });
      var avatarUrl = '';
      if (res.length == 1) {
        final image_field = env.orpc.sessionId!.serverVersion >= 13
            ? 'image_128'
            : 'image_small';
        var unique = res[0]['__last_update'] as String;
        unique = unique.replaceAll(RegExp(r'[^0-9]'), '');
        avatarUrl = env.orpc.baseURL +
            '/web/image?model=$modelName&field=$image_field&id=$userId&unique=$unique';
        res[0]['image_small'] = avatarUrl;
      } else {
        res.add(publicUserJson);
      }
      return res;
    } on OdooSessionExpiredException {
      return [publicUserJson];
    } on Exception {
      return [];
    }
  }
}
