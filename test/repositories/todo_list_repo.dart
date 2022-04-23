import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

// Todo list holds todo items
class TodoList extends Equatable implements OdooRecord {
  @override
  final int id;
  final String name;
  final String? kind;
  final List<dynamic> items;

  TodoList(this.id, this.name, {this.kind, this.items = const []});

  @override
  Map<String, dynamic> toVals() {
    return {'name': name, 'kind': kind ?? false};
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'kind': kind, 'items': items};
  }

  static TodoList fromJson(Map<String, Object> json) {
    return TodoList(
      json['id'] as int,
      json['name'] as String,
      kind: json['kind'] as String?,
      // Usually comes as list of tuples (id, display_name)
      items: json['item_ids'] as List<dynamic>,
    );
  }

  /// List of fields to fetch
  static List<String> get oFields => ['id', 'name', 'kind', 'item_ids'];

  // Equatable stuff to compare records
  @override
  List<Object> get props => [id, name];
}

class TodoListRepository extends OdooRepository<TodoList> {
  @override
  final modelName = 'todo.list';

  TodoListRepository(OdooEnvironment env) : super(env);
}
