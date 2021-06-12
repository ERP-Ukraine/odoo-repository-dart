import 'package:crypto/crypto.dart';
import 'dart:convert';

const odooServerURL = 'https://my-demo.odoo.com';
const String odooDbName = 'odoo';
// Hive
final hiveBoxName = sha1
    .convert(utf8.encode('odoo_repository_demo:$odooServerURL:$odooDbName'))
    .toString();
const cacheSessionKey = 'session';
