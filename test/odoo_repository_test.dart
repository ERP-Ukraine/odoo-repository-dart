import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:test/test.dart';

import 'dependencies/net_conn_impl.dart';
import 'dependencies/odoo_kv_map_impl.dart';
import 'repositories/todo_list_item_repo.dart';
import 'repositories/todo_list_repo.dart';

http_testing.MockClientHandler getFakeRequestHandler({final int code = 200}) {
  String checksum(String payload) {
    var bytes = utf8.encode(payload);
    return sha256.convert(bytes).toString();
  }

  var listIndex = 1;
  var itemIndex = 1;

  Future<http.Response> fakeRequestHandler(http.Request request) {
    // multiple cookies joined with comma
    dynamic result;
    String? error;
    final headers = {
      'Content-type': 'application/json',
      'set-cookie': '__cfduid=d7aa416b09272df9c8ooooooo84f5d031615155878'
          '; expires=Tue, 06-Apr-21 22:24:38 GMT'
          '; path=/; domain=.mhfly.com; HttpOnly'
          '; SameSite=Lax,session_id=${checksum(request.url.path)}'
          '; Expires=Sat, 05-Jun-2021 22:24:38 GMT; Max-Age=7776000'
          '; HttpOnly; Path=/'
    };

    final requestData = json.decode(request.body);
    var body = '{}';

    if (request.url.path.contains('/web/session/authenticate')) {
      final bodyJson = {
        'jsonrpc': '2.0',
        'id': requestData['id'],
        'result': {
          'id': 'session_id',
          'uid': requestData['params']['login'] == 'admin' ? 1 : 2,
          'partner_id': 2,
          'company_id': 1,
          'username': requestData['params']['login'],
          'name': 'admin',
          'user_context': {'tz': 'UTC', 'lang': 'en_US'},
          'is_system': true,
          'db': requestData['params']['db'],
          'server_version_info': [13]
        }
      };
      body = json.encode(bodyJson);
    } else {
      if (code == 200) {
        final requestParams =
            requestData['params'] as Map<String, dynamic>? ?? {};
        final model = requestParams['model'] as String;
        final method = requestParams['method'] as String;

        if (model == 'todo.list') {
          if (method == 'create') {
            result = [listIndex];
            listIndex += 1;
          }
          if (method == 'web_search_read') {
            result = {'length': 0, 'records': []};
          }
        }
        if (model == 'todo.list.item') {
          if (method == 'create') {
            if (requestParams['args'][0]['list_id'] as int > listIndex) {
              error = 'Wrong list_id index';
            }
            result = [itemIndex];
            itemIndex += 1;
          }
          if (method == 'web_search_read') {
            result = {
              'length': 0,
              'records': [
                {'id': 1, 'name': 'Milk', 'done': true, 'list_id': 1}
              ]
            };
          }
        }
        final bodyJson = {
          'jsonrpc': '2.0',
          'id': requestData['id'],
          'result': result
        };
        if (error != null) {
          bodyJson['error'] = {'code': 500, 'error': error};
        }
        body = json.encode(bodyJson);
      }
      if (code == 100) {
        body = '{"error": {"code": 100, "message": "Odoo Session Expired"}}';
      }
      if (code == 500) {
        body = '{"error": {"code": 400, "message": "Internal Server Error"}}';
      }
    }

    final response = http.Response(body, code, headers: headers);
    return Future<http.Response>.sync(() => response);
  }

  return fakeRequestHandler;
}

void main() async {
  late OdooKvMap cache;
  late NetworkConnectivity netConn;
  late http_testing.MockClient mockHttpClient;
  late OdooClient odooClient;
  late OdooEnvironment env;
  late TodoListRepository todoListRepo;
  late TodoListItemRepository todoListItemRepo;

  setUp(() async {
    cache = OdooKvMap();
    await cache.init();

    mockHttpClient = http_testing.MockClient(getFakeRequestHandler());

    odooClient = OdooClient('https://test.odoo.com', null, mockHttpClient);
    // Catch session changes to store most recent one
    final sessionChangedHandler = storeSesion(cache);
    odooClient.sessionStream.listen(sessionChangedHandler);

    netConn = NetworkConnectivity();

    env = OdooEnvironment(odooClient, 'odoo', cache, netConn);

    todoListRepo = env.add(TodoListRepository(env));
    todoListItemRepo = env.add(TodoListItemRepository(env));
  });

  test('env.of and env.models returning correct repo', () {
    expect(env.of<TodoListRepository>(), equals(todoListRepo));
    expect(env.of<TodoListItemRepository>(), equals(todoListItemRepo));
    expect(env.models[todoListRepo.modelName], equals(todoListRepo));
    expect(env.models[todoListItemRepo.modelName], equals(todoListItemRepo));
  });

  test('correct auth status', () async {
    expect(todoListRepo.isAuthenticated, equals(false));
    await odooClient.authenticate(env.dbName, 'admin', 'admin');
    expect(todoListRepo.isAuthenticated, equals(true));
  });

  test('cache keys are unique', () async {
    final env1Db1 = OdooEnvironment(
        OdooClient('https://test1.odoo.com', null, mockHttpClient),
        'db1',
        cache,
        netConn);
    final env2Db1 = OdooEnvironment(
        OdooClient('https://test2.odoo.com', null, mockHttpClient),
        'db1',
        cache,
        netConn);

    final env1Db2 = OdooEnvironment(
        OdooClient('https://test1.odoo.com', null, mockHttpClient),
        'db2',
        cache,
        netConn);
    final env2Db2 = OdooEnvironment(
        OdooClient('https://test2.odoo.com', null, mockHttpClient),
        'db2',
        cache,
        netConn);
    final env2Db2Demo = OdooEnvironment(
        OdooClient('https://test2.odoo.com', null, mockHttpClient),
        'db2',
        cache,
        netConn);

    final repo11 = env1Db1.add(TodoListRepository(env1Db1));
    final repo21 = env2Db1.add(TodoListRepository(env2Db1));
    final repo12 = env1Db2.add(TodoListRepository(env1Db2));
    final repo22 = env2Db2.add(TodoListRepository(env2Db2));
    final repo22Demo = env2Db2Demo.add(TodoListRepository(env2Db2Demo));

    await repo11.env.orpc.authenticate(repo11.env.dbName, 'admin', 'admin');
    await repo21.env.orpc.authenticate(repo21.env.dbName, 'admin', 'admin');
    await repo12.env.orpc.authenticate(repo12.env.dbName, 'admin', 'admin');
    await repo22.env.orpc.authenticate(repo22.env.dbName, 'admin', 'admin');
    await repo22Demo.env.orpc
        .authenticate(repo22Demo.env.dbName, 'demo', 'demo');

    // different domain, same db name
    expect(repo11.cacheKeySignature, isNot(equals(repo21.cacheKeySignature)));
    // same domain, different db name
    expect(repo11.cacheKeySignature, isNot(equals(repo12.cacheKeySignature)));
    // different domain, different db
    expect(repo11.cacheKeySignature, isNot(equals(repo22.cacheKeySignature)));
    // same domain, same db, different user
    expect(
        repo22.cacheKeySignature, isNot(equals(repo22Demo.cacheKeySignature)));
  });

  test('store mapping for fake ids', () async {
    final list1 = TodoList(todoListRepo.nextId, 'Shopping', kind: 'Private');
    final list2 = TodoList(todoListRepo.nextId, 'Project 1', kind: 'Work');

    var completer = Completer<Null>();
    netConn.onNetConnChanged.listen((netConnState netState) {
      if (netState == netConnState.online) {
        completer.complete();
      }
    });

    expect(list1.id, isNot(equals(list2.id)));

    await odooClient.authenticate(env.dbName, 'admin', 'admin');
    netConn.goOffline();
    await todoListRepo.create(list1);
    await todoListRepo.create(list2);
    netConn.goOnline();

    await completer.future;
    await env.callsLock.protectRead(() async => {});

    final mapping = todoListRepo.newIdMapping;
    expect(mapping.containsKey(list1.id), isTrue);
    expect(mapping.containsKey(list2.id), isTrue);
    expect(mapping[list1.id], isNot(equals(mapping.containsKey(list2.id))));
  });

  test('replace fake odoo id with real one in offline', () async {
    final list1 = TodoList(todoListRepo.nextId, 'Shopping', kind: 'Private');
    final item1 = TodoListItem(todoListItemRepo.nextId, 'Milk', false,
        OdooId(todoListRepo.modelName, list1.id));

    var completer = Completer<Null>();
    netConn.onNetConnChanged.listen((netConnState netState) {
      if (netState == netConnState.online) {
        completer.complete();
      }
    });

    await odooClient.authenticate(env.dbName, 'admin', 'admin');
    netConn.goOffline();
    await todoListRepo.create(list1);
    await todoListItemRepo.create(item1);
    netConn.goOnline();

    await completer.future;
    await env.callsLock.protectRead(() async => {});

    final mapping = todoListRepo.newIdMapping;
    expect(mapping.containsKey(list1.id), isTrue);
    var calls = await env.pendingCalls;
    expect(calls.isEmpty, isTrue);
  });

  test('replace fake odoo id with real one in online', () async {
    final list1 = TodoList(todoListRepo.nextId, 'Shopping', kind: 'Private');
    final item1 = TodoListItem(todoListItemRepo.nextId, 'Milk', false,
        OdooId(todoListRepo.modelName, list1.id));

    await odooClient.authenticate(env.dbName, 'admin', 'admin');
    await todoListRepo.create(list1);
    await todoListItemRepo.create(item1);

    await env.callsLock.protectRead(() async => {});

    final mapping = todoListRepo.newIdMapping;
    expect(mapping.containsKey(list1.id), isTrue);
    var calls = await env.pendingCalls;
    expect(calls.isEmpty, isTrue);
  });

  test('create and update related record in online', () async {
    final list1 = TodoList(todoListRepo.nextId, 'Shopping', kind: 'Private');
    final item1 = TodoListItem(todoListItemRepo.nextId, 'Milk', false,
        OdooId(todoListRepo.modelName, list1.id));

    await odooClient.authenticate(env.dbName, 'admin', 'admin');
    await todoListRepo.create(list1);
    await todoListItemRepo.create(item1);
    await todoListItemRepo.write(item1.copyWith(done: true));

    await env.callsLock.protectRead(() async => {});

    final latestRecords = todoListItemRepo.latestRecords;
    expect(latestRecords.length, equals(1));
    expect(latestRecords[0].done, isTrue);
    expect(latestRecords[0].id, equals(1));
  });
}
