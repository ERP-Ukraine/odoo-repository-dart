import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:pedantic/pedantic.dart';

import 'kv_store.dart';
import 'network_connection_state.dart';
import 'odoo_record.dart';

/// Base class of Odoo repository logic with RPC calls and local caching.
/// It sends stream events on record changes.
/// On read operation at first cached value is returned then async RPC call
/// is issued. When RPC response arrives stream gets update with fresh value.
class OdooRepository<R extends OdooRecord> {
  /// Holds current Odoo records
  List<R> latestRecords = [];

  List<dynamic> domain = [
    [1, '=', 1]
  ];

  /// holds total number of records in remote database.
  int remoteRecordsCount = 0;

  /// fetch limit
  int limit = 80;

  /// offset when fetching records.
  /// Normally it should be zero.
  /// It can be increased to load more data for list view
  /// without clearing a cache. See [cacheMoreRecords]
  int _offset = 0;

  set offset(int value) {
    if (value < 0) value = 0;
    if (value > remoteRecordsCount) value = remoteRecordsCount;
    _offset = value;
  }

  int get offset => _offset;

  /// Allows to change default order when fetching data.
  String order = '';

  /// True if local cache contails less records that remote db.
  bool get canLoadMore => _offset < remoteRecordsCount;

  // Duration in ms for throttling RPC calls
  int throttleDuration = 1000;

  // Tells if throttling is active now
  bool _isThrottling = false;

  /// Not null if call queque is currently processing
  Future<Null>? processingQueue;

  /// Odoo RPC client
  late OdooClient orpc;
  // Key-value cache client
  late OdooKv cache;

  /// Tells whether we should send record change events to a stream.
  /// Activates when there is at least one listener.
  bool recordStreamActive = false;

  /// Record change events stream controller
  late StreamController<List<R>> recordStreamController;

  /// Returns stream of record changed events
  Stream<List<R>> get recordStream => recordStreamController.stream;

  /// Odoo ORM model name. E.g. 'res.partner'
  /// Must be overridden to set real model name.
  late String modelName;

  /// Tracks current network state: online or offline
  late NetConnState netConnectivity;

  /// Only debug messages
  late Logger logger;

  /// Instantiates [OdooRepository] with given [OdooClient].
  OdooRepository(this.orpc, this.cache, this.netConnectivity)
      : logger = Logger() {
    recordStreamController = StreamController<List<R>>.broadcast(
        onListen: startSteam, onCancel: stopStream);
    netConnectivity.onNetConnChanged.listen(onNetworkConnChanged);
  }

  /// Enables stream of records fetched
  void startSteam() => recordStreamActive = true;

  /// Disables stream of records fetched
  void stopStream() => recordStreamActive = false;

  /// Unique identifier of remote Odoo instance
  String get serverUuid {
    if (!isAuthenticated) {
      throw OdooException('Not Authenticated');
    }
    return sha1
        .convert(utf8.encode('${orpc.baseURL}${orpc.sessionId!.dbName}'))
        .toString();
  }

  /// Gets unique part of a key for
  /// caching records of [modelName] of database per user
  String get cacheKeySignature {
    if (!isAuthenticated) {
      throw OdooException('Not Authenticated');
    }
    return '$serverUuid:${orpc.sessionId!.userId}:$modelName';
  }

  /// Returns cache key prefix to store call with unique key name
  String get rpcCallKeyPrefix {
    return 'OdooRpcCall:$cacheKeySignature:';
  }

  /// Returns prefix that is used caching records of [modelName] of database
  String get recordCacheKeyPrefix {
    if (!isAuthenticated) {
      throw OdooException('Not Authenticated');
    }
    return 'OdooRecord:$cacheKeySignature:';
  }

  /// Returns cache key to store record ids of current model.
  /// Unique per url+db+user+model.
  String get recordIdsCacheKey => 'OdooRecordIds:$cacheKeySignature';

  /// Sends empty list of records to a stream
  void clearRecords() {
    latestRecords = [];
    if (recordStreamActive) {
      recordStreamController.add([]);
    }
  }

  /// Returns cache key name by record [id]
  String getrecordCacheKey(int id) {
    return '$recordCacheKeyPrefix$id';
  }

  /// Deletes all cached records
  void clearCaches() {
    try {
      final keyPrefix = recordCacheKeyPrefix;
      for (String key in cache.keys) {
        if (key.contains(keyPrefix)) {
          cache.delete(key);
        }
      }
    } catch (e) {
      // clearCaches might be called when session already expired
      // and recordCacheKeyPrefix can't be computed
      return;
    }
  }

  /// Stores [record] in cache
  void cachePut(R record) {
    if (isAuthenticated) {
      final key = getrecordCacheKey(record.id);
      cache.put(key, record);
    }
  }

  /// Deletes [record] from cache
  void cacheDelete(R? record) {
    if (isAuthenticated && record != null) {
      final key = getrecordCacheKey(record.id);
      cache.delete(key);
    }
  }

  /// Gets record from cache by record's [id] (odoo id).
  R? cacheGet(int id) {
    if (isAuthenticated) {
      final key = getrecordCacheKey(id);
      try {
        return cache.get(key, defaultValue: null);
      } on Exception {
        cache.delete(key);
        return null;
      }
    }
    return null;
  }

  /// Returns currently cached records
  List<R> get _cachedRecords {
    if (!isAuthenticated) {
      throw OdooException('You must be authenticted to access $modelName');
    }
    // take list of cached ids and fetch corresponding records
    var ids = cache.get(recordIdsCacheKey, defaultValue: []);
    var recordIDs = List<int>.from(ids);
    var cachedRecords = <R>[];
    for (var recordID in recordIDs) {
      var record = cacheGet(recordID);
      if (record != null) {
        cachedRecords.add(record);
      }
    }
    return cachedRecords;
  }

  /// Get records from local cache and trigger remote fetch if not throttling
  List<R> get records {
    latestRecords = _cachedRecords;
    logger.d(
        '$modelName: Got ${latestRecords.length.toString()} records from cache.');
    if (!_isThrottling) {
      fetchRecords();
      _isThrottling = true;
      Timer(
          Duration(milliseconds: throttleDuration), () => _isThrottling = false);
    }
    return latestRecords;
  }

  /// Get records from remote.
  /// Must set [remoteRecordsCount]
  Future<List<dynamic>> searchRead() async {
    try {
      final Map<String, dynamic> response = await orpc.callKw({
        'model': modelName,
        'method': 'web_search_read',
        'args': [],
        'kwargs': {
          'context': {'bin_size': true},
          'domain': domain,
          'fields': OdooRecord.oFields,
          'limit': limit,
          'offset': offset,
          'order': order
        },
      });
      remoteRecordsCount = response['length'] as int;
      return response['records'] as List<dynamic>;
    } on Exception {
      remoteRecordsCount = 0;
      return [];
    }
  }

  /// Must be overridden to create real record from json
  R createRecordFromJson(Map<String, dynamic> json) {
    return OdooRecord(0) as R;
  }

  /// Fetch records from remote and push to the stream
  Future<void> fetchRecords() async {
    /// reset offset as if we are loading first page.
    /// To fetch more than that use [cacheMoreRecords].
    offset = 0;
    try {
      final res = await searchRead();
      if (res.isNotEmpty) {
        var freshRecordsIDs = <int>[];
        var freshRecords = <R>[];
        clearCaches();
        for (Map<String, dynamic> item in res) {
          var record = createRecordFromJson(item);
          freshRecordsIDs.add(record.id);
          freshRecords.add(record);
          cachePut(record);
        }
        if (freshRecordsIDs.isNotEmpty) {
          await cache.delete(recordIdsCacheKey);
          await cache.put(recordIdsCacheKey, freshRecordsIDs);
          latestRecords = freshRecords;
          if (recordStreamActive && isAuthenticated) {
            recordStreamController.add(latestRecords);
          }
        }
      }
    } on Exception {
      logger.d('$modelName: frontend_get_requests: OdooException}');
    }
  }

  /// Fetches more records from remote and adds them to list of cached records.
  /// Supposed to be used with list views.
  Future<void> cacheMoreRecords() async {
    offset += limit;
    try {
      final res = await searchRead();
      if (res.isEmpty) return;
      var cachedRecords = _cachedRecords;
      for (Map<String, dynamic> item in res) {
        var record = createRecordFromJson(item);
        cachedRecords.add(record);
        cachePut(record);
      }
      await cache.delete(recordIdsCacheKey);
      await cache.put(recordIdsCacheKey, cachedRecords.map((e) => e.id));
      latestRecords = cachedRecords;
      if (recordStreamActive && isAuthenticated) {
        recordStreamController.add(latestRecords);
      }
    } on Exception {
      logger.d('$modelName: frontend_get_requests: OdooException}');
    }
  }

  // Public methods

  bool get isAuthenticated =>
      orpc.sessionId != null && orpc.sessionId?.id != '';

  /// To be implemented in concrete class
  R create(Map<String, dynamic> values) {
    return createRecordFromJson({'id': 0});
  }

  /// To be implemented in concrete class
  List<R> search(List<List<dynamic>> domain, {int? limit, String? order}) {
    return [];
  }

  /// To be implemented in concrete class
  bool write(R record, Map<String, dynamic> values) {
    return false;
  }

  /// Unlink record on remote db.
  bool unlink(R record) {
    logger.d('$modelName: unlink id=${record.id}');
    execute(recordId: record.id, method: 'unlink')
        .then((res) => cacheDelete(record))
        .catchError((e) {
      if (e is OdooException) {
        return;
      }
    });
    return true;
  }

  /// Helps to builds rpc call instance.
  OdooRpcCall buildRpcCall(String method, int recordId, List<dynamic> args,
      Map<String, dynamic> kwargs) {
    return OdooRpcCall(
      orpc.sessionId!.userId,
      orpc.baseURL,
      orpc.sessionId!.dbName,
      modelName,
      recordId,
      method,
      args,
      kwargs,
    );
  }

  /// Puts [rpcCall] to calls queue that will be processed when online
  void queueRequest(OdooRpcCall rpcCall) {
    cache.put(rpcCall.cacheKey, rpcCall);
  }

  List<OdooRpcCall> get callsToProcess {
    var calls = <OdooRpcCall>[];
    if (!isAuthenticated) {
      return calls;
    }
    for (String key in cache.keys) {
      if (key.contains(rpcCallKeyPrefix)) {
        calls.add(cache.get(key));
      }
    }
    return calls;
  }

  /// Executes rpc calls
  Future<List<OdooRpcCall>> executeCalls(List<OdooRpcCall> calls) async {
    var executedCalls = <OdooRpcCall>[];
    logger.d('Processing call queue of `${calls.length}`');
    for (var call in calls) {
      logger.d('call key ${call.cacheKey}');
      try {
        final params = {
          'model': call.modelName,
          'method': call.method,
          'args': call.args.isNotEmpty ? [call.args] : [],
          'kwargs': call.kwargs,
        };
        final res = await orpc.callKw(params);
        logger.d(res.toString());
        executedCalls.add(call);
      } catch (e) {
        logger.d(e.toString());
      }
    }
    return executedCalls;
  }

  Future<void> handleExecutedCalls(List<OdooRpcCall> calls) async {
    print('processed ${calls.length} calls of `$modelName`');
    for (var call in calls) {
      logger.d('deleting key: `${call.cacheKey}`');
      await cache.delete(call.cacheKey);
    }
    unawaited(fetchRecords());
  }

  /// Processes call queue. Is called when online.
  void processCallQueue() async {
    if (!isAuthenticated) {
      return;
    }
    if (processingQueue == null) {
      final callsTodo = callsToProcess;
      if (callsTodo.isNotEmpty) {
        var completer = Completer<Null>();
        processingQueue = completer.future;
        final executedCalls = await executeCalls(callsTodo);
        await handleExecutedCalls(executedCalls);
        logger.d('Unlocking calls queue of `$modelName`');
        completer.complete();
        processingQueue = null;
      } else {
        unawaited(fetchRecords());
      }
    } else {
      logger.d('Queue processing of $modelName is already running');
    }
  }

  /// Called when going online/offline
  void onNetworkConnChanged(netConnState netState) {
    if (netState == netConnState.online) {
      // process call queue
      processCallQueue();
    }
  }

  /// Executes [method] on [recordId] of current [modelName].
  /// It places call to queue that is processed either immediately if
  /// network is online or when network state will be changed to online.
  Future<dynamic> execute(
      {required int recordId,
      required String method,
      List<dynamic> args = const [],
      Map<String, dynamic> kwargs = const {}}) async {
    final rpcCall = buildRpcCall(method, recordId, args, kwargs);
    queueRequest(rpcCall);
    if (await netConnectivity.checkNetConn() == netConnState.online) {
      processCallQueue();
    }
  }
}
