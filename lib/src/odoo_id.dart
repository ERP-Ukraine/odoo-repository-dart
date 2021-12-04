import 'package:equatable/equatable.dart';

/// Represents Odoo database id.
/// It might be fake if record was created in offline mode.
class OdooId extends Equatable {
  final String odooModel;
  final int odooId;

  OdooId(this.odooModel, this.odooId);

  /// Converts [OdooId] to JSON
  Map<String, Object> toJson() {
    return {'odooModel': odooModel, 'odooId': odooId};
  }

  /// Creates [OdooId] from JSON
  static OdooId fromJson(Map<String, dynamic> json) {
    return OdooId(json['odooModel'] as String, json['odooId'] as int);
  }

  /// Equatable
  @override
  List<Object> get props => [odooModel, odooId];
}
