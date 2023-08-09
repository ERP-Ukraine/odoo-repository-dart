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

  TodoListItem copyWith(
      {int? id, String? name, bool? done, OdooId? todoListId}) {
    return TodoListItem(id ?? this.id, name ?? this.name, done ?? this.done,
        todoListId ?? this.todoListId);
  }

  @override
  Map<String, dynamic> toVals() {
    return {'name': name, 'done': done, 'list_id': todoListId};
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'done': done, 'list_id': todoListId};
  }

  static TodoListItem fromJson(Map<String, dynamic> json) {
    late OdooId listOdooId;
    var listId = json['list_id'] as int?;
    if (listId == null) {
      listOdooId = json['list_id'] as OdooId;
    } else {
      listOdooId = OdooId('todo.list', listId);
    }
    return TodoListItem(
      json['id'] as int,
      json['name'] as String,
      json['done'] as bool,
      listOdooId,
    );
  }

  /// List of fields to fetch
  static List<String> get oFields => ['id', 'name', 'done', 'list_id'];

  // Equatable stuff to compare records
  @override
  List<Object> get props => [id, name, done, todoListId];
}

class TodoListItemRepository extends OdooRepository<TodoListItem> {
  // TODO: override getter
  @override
  final modelName = 'todo.list.item';

  TodoListItemRepository(OdooEnvironment env) : super(env);

  @override
  TodoListItem createRecordFromJson(Map<String, dynamic> json) {
    return TodoListItem.fromJson(json);
  }
}
