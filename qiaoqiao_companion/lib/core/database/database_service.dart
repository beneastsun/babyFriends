import 'package:shared_preferences/shared_preferences.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 数据库服务 - 统一管理所有 DAO
class DatabaseService {
  static DatabaseService? _instance;

  final AppDatabase _database;

  late final AppUsageDao appUsageDao;
  late final RuleDao ruleDao;
  late final PointsDao pointsDao;
  late final CouponDao couponDao;
  late final DailyStatsDao dailyStatsDao;
  late final AppCategoryDao appCategoryDao;

  DatabaseService._(this._database) {
    appUsageDao = AppUsageDao(_database);
    ruleDao = RuleDao(_database);
    pointsDao = PointsDao(_database);
    couponDao = CouponDao(_database);
    dailyStatsDao = DailyStatsDao(_database);
    appCategoryDao = AppCategoryDao(_database);
  }

  /// 获取单例实例
  static Future<DatabaseService> getInstance() async {
    if (_instance == null) {
      final database = AppDatabase.instance;
      await database.database; // 确保数据库已初始化
      _instance = DatabaseService._(database);
    }
    return _instance!;
  }

  /// 初始化数据库（包括默认数据）
  Future<void> initialize() async {
    // 导入预设应用分类
    await appCategoryDao.deleteAll();
    await appCategoryDao.importPresets(PresetAppCategories.presets);

    // 检查是否已有规则，如果没有则插入默认规则
    final rules = await ruleDao.getAll();
    if (rules.isEmpty) {
      await ruleDao.insertDefaultRules();
    } else {
      // 清理旧的默认规则（v1.0 之前版本的默认规则）
      // 删除所有 timeBlock 类型的规则（睡觉时间、上课时间等禁用时段）
      // 删除所有 appCategory 类型的规则（游戏、视频类别限制）
      await _cleanupOldDefaultRules();
    }
  }

  /// 清理旧的默认规则
  ///
  /// v1.0 之前版本默认包含：
  /// - 睡觉时间禁用时段 (21:00-07:00)
  /// - 上课时间禁用时段 (09:00-12:00, 14:00-17:00)
  /// - 游戏类限制 (30分钟)
  /// - 视频类限制 (30分钟)
  /// - 总时间限制 (工作日3小时，周末4小时)
  ///
  /// v1.1 版本默认不做任何限制，让家长自行设置规则
  ///
  /// 注意：此方法只在首次检测到旧版本规则时执行一次
  /// 使用 SharedPreferences 标记已清理，避免重复执行
  Future<void> _cleanupOldDefaultRules() async {
    // 检查是否已经清理过
    final prefs = await SharedPreferences.getInstance();
    final alreadyCleaned = prefs.getBool('old_rules_cleaned') ?? false;
    if (alreadyCleaned) {
      print('[DatabaseService] 旧规则已清理过，跳过');
      return;
    }

    final db = await _database.database;

    // 删除所有 timeBlock 类型的规则（禁用时段）
    await db.delete(
      DatabaseConstants.tableRules,
      where: 'rule_type = ?',
      whereArgs: ['time_block'],
    );

    // 删除所有 appCategory 类型的规则（游戏、视频限制）
    await db.delete(
      DatabaseConstants.tableRules,
      where: 'rule_type = ?',
      whereArgs: ['app_category'],
    );

    // 注意：不再禁用 totalTime 规则！
    // 用户自己设置的规则应该保留其 enabled 状态

    // 标记已清理
    await prefs.setBool('old_rules_cleaned', true);
    print('[DatabaseService] 旧规则清理完成');
  }

  /// 关闭数据库
  Future<void> close() async {
    await _database.close();
    _instance = null;
  }

  /// 清空所有数据
  Future<void> clearAllData() async {
    await _database.clearAllTables();
  }
}
