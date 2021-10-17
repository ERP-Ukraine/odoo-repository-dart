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

  PartnerRepository(OdooDatabase database) : super(database);

  @override
  Partner createRecordFromJson(Map<String, dynamic> json) {
    return Partner.fromJson(json);
  }
}
```

At first we need to Instantiate `OdooEnvironment` that holds list of Odoo Repositories
and executes call queue in same order as repositories were added to Environment.

`OdooEnvironment` requires `OdooClient`, database name, cache and network connectivity.
When it is instantianted new repository instances can be added via `add()` call.

```dart
// Init cache storage implemented with Hive
final cache = OdooKvHive();
await cache.init();
// Try to recover session from storage
OdooSession? session = cache.get('cacheSessionKey', defaultValue: null);
const odooServerURL = 'https://my-odoo-instance.com'
final odooClient = OdooClient(odooServerURL, session);
final netConn = NetworkConnectivity();
const odooDbName = 'odoo';

final env = OdooEnvironment(odooClient, odooDbName, cache, netConn);

final partnerRepo = env.add(PartnerRepository(env));
env.add(UserRepository(env));
env.add(SaleOrderRepository(env));
env.add(SaleOrderLineRepository(env));
// and so on
// later we can access instance of PartnerRepository via
final saleOrderRepo = env.of<SaleOrderRepository>();
final saleOrderLineRepo = saleOrderRepo.env.of<SaleOrderLineRepository>();
```

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
