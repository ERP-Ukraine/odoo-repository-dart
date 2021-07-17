# Odoo Models Repository

Abstraction layer to communicate with Odoo backend.

It helps to implement data communication between Odoo and dart client with persistance and offline mode.

## Features

- Static Types. Odoo records are represented with dart types.
- Offline mode. Records are stored to local cache.
- Call Queue. RPC calls are executed when network goes online.
- Records stream. Easily integrate data updates with BLoC or FutureBuilder.

## Description

Odoo Repository package uses `OdooRecord` as base class to represent record fetched from remote Odoo instance.

The record has following properties:

- has fields to store data;
- is immutable;
- can be compared to other record of same type for equality;
- can be converted to/from JSON.

The very basic `res.partner` record implementation.

```dart
import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

class Partner extends Equatable implements OdooRecord {
  const Partner(this.id, this.name);

  @override
  final int id;
  final String name;

  /// Converts Partner to JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  /// Creates [Partner] from JSON
  static Partner fromJson(Map<String, dynamic> json) {
    return Partner(
      json['id'] as int;
      json['name'] as String,
    );
  }

  /// Equatable stuff to compare records
  @override
  List<Object> get props => [id, name];

  /// List of fields we need to fetch from Odoo
  static List<String> get oFields => ['id', 'name'];

  @override
  String toString() => 'User[$id]: $name';
}
```

Every Odoo model that has to be fetched needs to have own pair of `OdooRecord` and `OdooRepository` implementations.

After having `Partner` class implemented we can define `PartnerRepository` class
that is based on `OdooRepository` and configured with `Partner` type.

Very few things needs to be configured in order to make `PartnerRepository` class do it's job of providing `Partner` records.

```dart
import 'package:odoo_repository/odoo_repository.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'partner_record.dart';

class PartnerRepository extends OdooRepository<Partner> {
  @override
  final String modelName = 'res.partner';

  PartnerRepository(
    OdooClient orpc, String dbName, OdooKv cache, NetConnState netConn)
      : dbName = dbName,
        super(orpc, cache, netConn) {
          // In case we want to pre-fetch records right after login
          // instead of when they are actually needed.
          orpc.loginStream.listen(loginStateChanged);
        }

  void loginStateChanged(OdooLoginEvent event) {
    if (event == OdooLoginEvent.loggedIn) {
      fetchRecords();
      processCallQueue();
    }
    if (event == OdooLoginEvent.loggedOut) {
      clearRecords();
    }
  }

  @override
  Partner createRecordFromJson(Map<String, dynamic> json) {
    return Partner.fromJson(json);
  }
}
```

In order to instantiate `PartnerRepository` we also need to pass instance of key-value store
that implements `OdooKv` interface and instance of network connection monitoring class that implements `NetConnState` interface.

Here is an example how `NetConnState` can be implemented with [connectivity](https://pub.dev/packages/connectivity) package.

```dart
import 'package:connectivity/connectivity.dart';
import 'package:odoo_repository/odoo_repository.dart'
    show netConnState, NetConnState;

class NetworkConnectivity implements NetConnState {
  static NetworkConnectivity? _singleton;
  static late Connectivity _connectivity;

  factory NetworkConnectivity() {
    _singleton ??= NetworkConnectivity._();
    return _singleton!;
  }

  NetworkConnectivity._() {
    _connectivity = Connectivity();
  }

  @override
  Future<netConnState> checkNetConn() async {
    final connectivityResult = await (_connectivity.checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile) {
      return netConnState.online;
    } else if (connectivityResult == ConnectivityResult.wifi) {
      return netConnState.online;
    }
    return netConnState.offline;
  }

  @override
  Stream<netConnState> get onNetConnChanged async* {
    await for (var netState in _connectivity.onConnectivityChanged) {
      if (netState == ConnectivityResult.mobile) {
        // Went online now
        yield netConnState.online;
      } else if (netState == ConnectivityResult.wifi) {
        // Went online now
        yield netConnState.online;
      } else if (netState == ConnectivityResult.none) {
        // Went offline now
        yield netConnState.offline;
      }
    }
  }
}
```

For implementation of key-value store using Hive see example folder.

## Issues

Please file any issues, bugs or feature requests as an issue on our [GitHub](https://github.com/ERP-Ukraine/odoo-repository-dart/issues) page.

## Author

Odoo Repository Library is developed by [ERP Ukraine](https://erp.co.ua) – Odoo Silver Partner.
