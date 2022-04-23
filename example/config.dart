import 'dart:convert';

import 'package:crypto/crypto.dart';

const odooServerURL = 'https://my-demo.odoo.com';
const String odooDbName = 'odoo';
// Hive
final hiveBoxName = sha1
    .convert(utf8.encode('odoo_repository_demo:$odooServerURL:$odooDbName'))
    .toString();
const cacheSessionKey = 'session';
