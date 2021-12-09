import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import 'odoo_id.dart';

/// [OdooRpcCall] represents RPC call to Odoo database
/// It is used to store calls to persistent storage for later execution.
class OdooRpcCall extends Equatable {
  final int userId;
  final String baseURL;
  final String dbName;
  final String modelName;
  final int recordId;
  final String method;
  final dynamic args;
  final Map<dynamic, dynamic> kwargs;
  final DateTime callDate;
  // TODO: add call type: rpc, controller, etc

  OdooRpcCall(this.userId, this.baseURL, this.dbName, this.modelName,
      this.recordId, this.method, this.args, this.kwargs,
      [DateTime? callDate])
      : callDate = callDate ?? DateTime.now();

  /// Unique identifier of remote Odoo instance
  String get serverUuid {
    return sha1.convert(utf8.encode('$baseURL$dbName')).toString();
  }

  /// Cache key to store call
  String get cacheKey {
    var key = 'OdooRpcCall:$serverUuid:$userId:$modelName';
    key += ':$recordId:$method:${callDate.toString()}';
    return key;
  }

  @override
  List<Object> get props =>
      [userId, baseURL, dbName, modelName, method, callDate];

  /// Used to store a call to persistant call queue.
  Map<String, Object> toJson() {
    return {
      'userId': userId,
      'baseURL': baseURL,
      'dbName': dbName,
      'modelName': modelName,
      'recordId': recordId,
      'method': method,
      'args': args,
      'kwargs': kwargs,
      'callDate': callDate.toIso8601String(),
    };
  }

  /// Used to restore a call from persistant call queue.
  static OdooRpcCall fromJson(Map<String, dynamic> jsonMap) {
    final callJson = json.encode(jsonMap, toEncodable: (value) {
      if (value is DateTime) {
        return value.toIso8601String();
      }
      if (value is OdooId) {
        return value.toJson();
      }
      return value;
    });
    return json.decode(callJson, reviver: (key, value) {
      if (value is Map) {
        if (value.containsKey('userId')) {
          return OdooRpcCall(
            value['userId'] as int,
            value['baseURL'] as String,
            value['dbName'] as String,
            value['modelName'] as String,
            value['recordId'] as int,
            value['method'] as String,
            value['args'] as dynamic,
            value['kwargs'] as Map<dynamic, dynamic>,
            DateTime.parse(value['callDate']),
          );
        }
        if (value.containsKey('odooModel') && value.containsKey('odooId')) {
          return OdooId(value['odooModel'] as String, value['odooId'] as int);
        }
      }
      return value;
    });
  }
}
