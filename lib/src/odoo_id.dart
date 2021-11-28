import 'package:equatable/equatable.dart';

/// Represents Odoo database id.
/// It might be fake if record was created in offline mode.
class OdooId extends Equatable {
  final int id;
  static const String kind = 'OdooId';

  OdooId(this.id);

  /// Converts [OdooId] to JSON
  Map<String, Object> toJson() {
    return {
      'id': id,
      'kind': kind,
    };
  }

  /// Creates [OdooId] from JSON
  static OdooId fromJson(Map<String, dynamic> json) {
    return OdooId(
      json['id'] as int,
    );
  }

  /// Equatable
  @override
  List<Object> get props => [id];
}
