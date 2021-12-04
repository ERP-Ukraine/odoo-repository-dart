import 'package:hive/hive.dart';
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:user_repository/user_repository.dart' show User;

import 'config.dart';

typedef SessionChangedCallback = void Function(OdooSession sessionId);

/// Implements persistent key-value storage for
/// Odoo records and session persistance with Hive
class OdooKvHive implements OdooKv {
  late Box box;

  OdooKvHive();

  @override
  Future<void> init() async {
    Hive.registerAdapter(OdooSessionAdapter());
    Hive.registerAdapter(OdooRpcCallAdapter());
    Hive.registerAdapter(OdooIdAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.init('/tmp');
    box = await Hive.openBox(hiveBoxName);
  }

  @override
  Future<void> close() {
    return box.close();
  }

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return box.get(key, defaultValue: defaultValue);
  }

  @override
  Future<void> put(dynamic key, dynamic value) {
    return box.put(key, value);
  }

  @override
  Future<void> delete(dynamic key) {
    return box.delete(key);
  }

  @override
  Iterable<dynamic> get keys => box.keys;
}

/// Callback for session changed events
SessionChangedCallback storeSesion(OdooKv cache) {
  void sessionChanged(OdooSession sessionId) {
    if (sessionId.id == '') {
      cache.delete(cacheSessionKey);
    } else {
      cache.put(cacheSessionKey, sessionId);
    }
  }

  return sessionChanged;
}

/// Adapter to store and read OdooSession from persistent storage
class OdooSessionAdapter extends TypeAdapter<OdooSession> {
  @override
  final typeId = 0;

  @override
  OdooSession read(BinaryReader reader) {
    return OdooSession.fromJson(Map<String, dynamic>.from(reader.read()));
  }

  @override
  void write(BinaryWriter writer, OdooSession obj) {
    writer.write(obj.toJson());
  }
}

/// Adapter to store and read OdooRpcCall to/from Hive
class OdooRpcCallAdapter extends TypeAdapter<OdooRpcCall> {
  @override
  final typeId = 2;

  @override
  OdooRpcCall read(BinaryReader reader) {
    return OdooRpcCall.fromJson(Map<String, dynamic>.from(reader.read()));
  }

  @override
  void write(BinaryWriter writer, OdooRpcCall obj) {
    writer.write(obj.toJson());
  }
}

/// Adapter to store and read OdooId to/from Hive
class OdooIdAdapter extends TypeAdapter<OdooId> {
  @override
  final typeId = 3;

  @override
  OdooId read(BinaryReader reader) {
    return OdooId.fromJson(Map<String, dynamic>.from(reader.read()));
  }

  @override
  void write(BinaryWriter writer, OdooId obj) {
    writer.write(obj.toJson());
  }
}

/// Adapter to store and read User to/from Hive
class UserAdapter extends TypeAdapter<User> {
  @override
  final typeId = 4;

  @override
  User read(BinaryReader reader) {
    return User.fromJson(Map<String, dynamic>.from(reader.read()));
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.write(obj.toJson());
  }
}
