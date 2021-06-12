import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// [OdooRpcCall] represents RPC call to Odoo database
/// It is used to store calls to persistent storage for later execution.
class OdooRpcCall extends Equatable {
  final int userId;
  final String baseURL;
  final String dbName;
  final String modelName;
  final int recordId;
  final String method;
  final List<dynamic> args;
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
      'callDate': callDate,
    };
  }

  /// Used to restore a call from persistant call queue.
  static OdooRpcCall fromJson(Map<String, dynamic> json) {
    return OdooRpcCall(
      json['userId'] as int,
      json['baseURL'] as String,
      json['dbName'] as String,
      json['modelName'] as String,
      json['recordId'] as int,
      json['method'] as String,
      json['args'] as List<dynamic>,
      json['kwargs'] as Map<dynamic, dynamic>,
      json['callDate'] as DateTime,
    );
  }
}
