import 'package:equatable/equatable.dart';
import 'package:odoo_repository/odoo_repository.dart';

// Represents todo item inside specific list
class TodoListItem extends Equatable implements OdooRecord {
  @override
  final int id;
  final String name;
  final bool done;
  final OdooId todoListId;

  TodoListItem(this.id, this.name, this.done, this.todoListId);

  @override
  Map<String, dynamic> toVals() {
    return {'name': name, 'done': done, 'list_id': todoListId};
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'done': done, 'list_id': todoListId};
  }

  static TodoListItem fromJson(Map<String, Object> json) {
    return TodoListItem(
      json['id'] as int,
      json['name'] as String,
      json['done'] as bool,
      json['list_id'] as OdooId,
    );
  }

  /// List of fields to fetch
  static List<String> get oFields => ['id', 'name', 'done', 'list_id'];

  // Equatable stuff to compare records
  @override
  List<Object> get props => [id, name, done, todoListId];
}

class TodoListItemRepository extends OdooRepository<TodoListItem> {
  @override
  final modelName = 'todo.list.item';

  TodoListItemRepository(OdooEnvironment env) : super(env);
}
