import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';

class TaskDefinitionDao {
  final AppDatabase _db;

  TaskDefinitionDao(this._db);

  Future<int> insert(TaskDefinition task) async {
    final database = await _db.database;
    return await database.insert(
      DatabaseConstants.tableTaskDefinitions,
      task.toMap(),
    );
  }

  Future<List<TaskDefinition>> getAll() async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskDefinitions,
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return maps.map(TaskDefinition.fromMap).toList();
  }

  Future<List<TaskDefinition>> getEnabled() async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskDefinitions,
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return maps.map(TaskDefinition.fromMap).toList();
  }

  Future<TaskDefinition?> getById(int id) async {
    final database = await _db.database;
    final maps = await database.query(
      DatabaseConstants.tableTaskDefinitions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TaskDefinition.fromMap(maps.first);
  }

  Future<int> update(TaskDefinition task) async {
    final database = await _db.database;
    return await database.update(
      DatabaseConstants.tableTaskDefinitions,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final database = await _db.database;
    return await database.delete(
      DatabaseConstants.tableTaskDefinitions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
