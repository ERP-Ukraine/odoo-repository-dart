import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

/// Pure Dart user model used in Flutter app.
class User extends Equatable implements OdooRecord {
  const User(this.id, this.partnerId, this.login, this.name, this.lang,
      this.imageSmall);

  // We create fake user with id = 0 in case we are not logged in
  factory User.publicUser() {
    return User(0, [], 'public', 'Public User', 'en_US', '');
  }

  bool get isPublic => id == 0 ? true : false;

  @override
  final int id;
  final List<dynamic> partnerId;
  final String login;
  final String name;
  final String lang;
  final String imageSmall;

  /// Converts [User] to JSON compatible with create or write
  /// For larger models better use code generation.
  @override
  Map<String, dynamic> toVals() {
    return {
      'id': id,
      'partner_id': partnerId,
      'login': login,
      'name': name,
      'lang': lang,
      'image_small': imageSmall
    };
  }

  /// Converts [User] to JSON
  /// For larger models better use code generation.
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partner_id': partnerId,
      'login': login,
      'name': name,
      'lang': lang,
      'image_small': imageSmall
    };
  }

  /// Creates [User] from JSON
  static User fromJson(Map<String, dynamic> json) {
    var userId = json['id'] as int? ?? 0;
    if (userId == 0) {
      return User.publicUser();
    }

    return User(
      userId,
      json['partner_id'] as List<dynamic>? ?? [],
      json['login'] as String? ?? '',
      json['name'] as String? ?? '',
      json['lang'] as String? ?? 'uk_UA',
      json['image_small'] as String? ?? '',
    );
  }

  // Equatable stuff to compare records
  @override
  List<Object> get props => [id, partnerId, login, name, lang, imageSmall];

  // List of fields we need to fetch
  static List<String> get oFields =>
      ['id', 'partner_id', 'login', 'name', 'lang', '__last_update'];

  @override
  String toString() => 'User[$id]: $name ($login)';
}
