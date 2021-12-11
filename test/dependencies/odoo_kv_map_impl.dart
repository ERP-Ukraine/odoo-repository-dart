import 'package:odoo_repository/odoo_repository.dart' show OdooKv;
import 'package:odoo_rpc/odoo_rpc.dart' show OdooSession;

typedef SessionChangedCallback = void Function(OdooSession sessionId);

const cacheSessionKey = 'session';

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

class OdooKvMap implements OdooKv {
  var _storage = <dynamic, dynamic>{};

  OdooKvMap();

  @override
  Future<void> init() async {
    _storage = {};
  }

  @override
  Future<void> close() async {
    _storage = {};
  }

  @override
  Iterable<dynamic> get keys => _storage.keys;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _storage[key] = value;
  }

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _storage.containsKey(key) ? _storage[key] : defaultValue;
  }

  @override
  Future<void> delete(dynamic key) async {
    _storage.remove(key);
  }
}
