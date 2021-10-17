/// [OdooRecord] is immutable representation of Odoo record.
class OdooRecord {
  final int id;

  /// Creates json from [OdooRecord] compatible with [fromJson].
  /// Used to cache records.
  Map<String, dynamic> toJson() {
    return {'id': id};
  }

  /// Creates [OdooRecord] from json returned by search_read() or cache.
  static OdooRecord fromJson(Map<String, Object> json) {
    return OdooRecord(json['id'] as int);
  }

  /// List of fields to fetch
  static List<String> get oFields => ['id', '__last_update'];

  const OdooRecord(this.id);
}
