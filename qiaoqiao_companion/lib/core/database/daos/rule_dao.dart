import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 规则 DAO
class RuleDao {
  final AppDatabase _database;

  RuleDao(this._database);

  Future<int> insert(Rule rule) async {
    final db = await _database.database;
    final map = rule.toMap();
    print('[RuleDao] insert: map=$map');
    final id = await db.insert(
      DatabaseConstants.tableRules,
      map,
    );
    print('[RuleDao] insert 成功, id=$id');
    return id;
  }

  Future<List<Rule>> getAll() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableRules,
      orderBy: 'rule_type, target',
    );
    final rules = maps.map((map) => Rule.fromMap(map)).toList();
    print('[RuleDao] getAll: 找到 ${rules.length} 条规则');
    for (final r in rules) {
      print('[RuleDao] 规则: id=${r.id}, type=${r.ruleType.code}, enabled=${r.enabled}');
    }
    return rules;
  }

  Future<List<Rule>> getByType(RuleType type) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableRules,
      where: 'rule_type = ?',
      whereArgs: [type.code],
      orderBy: 'target',
    );
    return maps.map((map) => Rule.fromMap(map)).toList();
  }

  Future<List<Rule>> getEnabled() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableRules,
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'rule_type, target',
    );
    return maps.map((map) => Rule.fromMap(map)).toList();
  }

  Future<Rule?> getById(int id) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableRules,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Rule.fromMap(maps.first);
  }

  Future<Rule?> getByTypeAndTarget(RuleType type, String? target) async {
    final db = await _database.database;
    String where = 'rule_type = ?';
    List<dynamic> whereArgs = [type.code];

    if (target != null) {
      where += ' AND target = ?';
      whereArgs.add(target);
    } else {
      where += ' AND target IS NULL';
    }

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableRules,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Rule.fromMap(maps.first);
  }

  Future<int> update(Rule rule) async {
    final db = await _database.database;
    final map = rule.toMap();
    print('[RuleDao] update: id=${rule.id}, map=$map');
    final count = await db.update(
      DatabaseConstants.tableRules,
      map,
      where: 'id = ?',
      whereArgs: [rule.id],
    );
    print('[RuleDao] update 成功, 影响行数=$count');
    return count;
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    return await db.delete(
      DatabaseConstants.tableRules,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tableRules);
  }

  /// 删除指定类型和目标的规则
  Future<int> deleteByTypeAndTarget(RuleType type, String? target) async {
    final db = await _database.database;
    if (target != null) {
      return await db.delete(
        DatabaseConstants.tableRules,
        where: 'rule_type = ? AND target = ?',
        whereArgs: [type.code, target],
      );
    } else {
      return await db.delete(
        DatabaseConstants.tableRules,
        where: 'rule_type = ? AND target IS NULL',
        whereArgs: [type.code],
      );
    }
  }

  /// 获取单个应用的规则
  Future<Rule?> getAppRule(String packageName) async {
    return await getByTypeAndTarget(RuleType.appSingle, packageName);
  }

  /// 批量插入默认规则
  Future<void> insertDefaultRules() async {
    final defaultRules = DefaultRules.createDefaultRules();
    for (final rule in defaultRules) {
      await insert(rule);
    }
  }

  /// 获取所有有限制规则的应用包名列表
  /// 包括：
  /// - RuleType.appSingle 规则的 target 字段（单个应用限制）
  /// - RuleType.appCategory 规则对应的分类应用（需要配合 AppCategoryDao）
  Future<Set<String>> getRestrictedPackageNames() async {
    final db = await _database.database;
    final Set<String> packageNames = {};

    // 获取单个应用限制的包名
    final appRules = await db.query(
      DatabaseConstants.tableRules,
      where: 'rule_type = ? AND enabled = ?',
      whereArgs: [RuleType.appSingle.code, 1],
    );
    for (final rule in appRules) {
      final target = rule['target'] as String?;
      if (target != null) {
        packageNames.add(target);
      }
    }

    // 获取分类限制的包名
    final categoryRules = await db.query(
      DatabaseConstants.tableRules,
      where: 'rule_type = ? AND enabled = ?',
      whereArgs: [RuleType.appCategory.code, 1],
    );
    if (categoryRules.isNotEmpty) {
      final categories = categoryRules
          .map((r) => r['target'] as String?)
          .whereType<String>()
          .toList();

      if (categories.isNotEmpty) {
        // 从 app_categories 表获取这些分类的应用包名
        final placeholders = List.filled(categories.length, '?').join(',');
        final categoryApps = await db.rawQuery(
          'SELECT DISTINCT package_name FROM ${DatabaseConstants.tableAppCategories} '
          'WHERE category IN ($placeholders)',
          categories,
        );
        for (final app in categoryApps) {
          final packageName = app['package_name'] as String?;
          if (packageName != null) {
            packageNames.add(packageName);
          }
        }
      }
    }

    return packageNames;
  }
}
