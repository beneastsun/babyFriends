import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 应用数据库帮助类
class AppDatabase {
  static Database? _database;

  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DatabaseConstants.databaseName);

    final db = await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // 确保性能优化索引存在（幂等操作，不会重复创建）
    await _ensurePerformanceIndexes(db);

    return db;
  }

  /// 确保性能优化索引存在
  /// 使用 IF NOT EXISTS 确保幂等性，对现有用户也生效
  Future<void> _ensurePerformanceIndexes(Database db) async {
    // 复合索引：用于按日期+包名查询使用记录
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_usage_date_package
      ON ${DatabaseConstants.tableAppUsageRecords}(date, package_name);
    ''');
    // 复合索引：用于按时段查询统计数据
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hourly_date_hour
      ON ${DatabaseConstants.tableHourlyUsageStats}(date, hour);
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建使用记录表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableAppUsageRecords} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT,
        category TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        date TEXT NOT NULL
      );
    ''');

    // 创建规则配置表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableRules} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rule_type TEXT NOT NULL,
        target TEXT,
        weekday_limit INTEGER,
        weekend_limit INTEGER,
        time_start TEXT,
        time_end TEXT,
        enabled INTEGER DEFAULT 1
      );
    ''');

    // 创建积分流水表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tablePointsHistory} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        change INTEGER NOT NULL,
        reason TEXT NOT NULL,
        balance_after INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');

    // 创建加时券表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCoupons} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        duration INTEGER NOT NULL,
        source TEXT NOT NULL,
        status TEXT DEFAULT 'available',
        expires_at INTEGER,
        used_at INTEGER,
        created_at INTEGER NOT NULL
      );
    ''');

    // 创建每日统计表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableDailyStats} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE NOT NULL,
        total_duration INTEGER DEFAULT 0,
        game_duration INTEGER DEFAULT 0,
        video_duration INTEGER DEFAULT 0,
        study_duration INTEGER DEFAULT 0,
        points_earned INTEGER DEFAULT 0,
        rules_followed INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 创建应用分类表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableAppCategories} (
        package_name TEXT PRIMARY KEY,
        app_name TEXT,
        category TEXT NOT NULL,
        custom INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 创建小时级使用统计表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableHourlyUsageStats} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        hour INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        app_name TEXT,
        category TEXT,
        duration_seconds INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL,
        UNIQUE(date, hour, package_name) ON CONFLICT REPLACE
      );
    ''');

    // v3 新增：被监控应用表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableMonitoredApps} (
        package_name TEXT PRIMARY KEY,
        app_name TEXT,
        daily_limit_minutes INTEGER,
        category TEXT,
        enabled INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    // v3 新增：时间段表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableTimePeriods} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mode TEXT NOT NULL,
        time_start TEXT NOT NULL,
        time_end TEXT NOT NULL,
        days TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL
      );
    ''');

    // v3 新增：连续使用会话表
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableContinuousSessions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_date TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        total_duration_seconds INTEGER DEFAULT 0,
        last_activity_time INTEGER,
        rest_end_time INTEGER,
        alerts_shown TEXT,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 创建索引
    await db.execute('''
      CREATE INDEX idx_usage_records_date ON ${DatabaseConstants.tableAppUsageRecords}(date);
    ''');
    await db.execute('''
      CREATE INDEX idx_usage_records_package ON ${DatabaseConstants.tableAppUsageRecords}(package_name);
    ''');
    await db.execute('''
      CREATE INDEX idx_points_history_created ON ${DatabaseConstants.tablePointsHistory}(created_at);
    ''');
    await db.execute('''
      CREATE INDEX idx_daily_stats_date ON ${DatabaseConstants.tableDailyStats}(date);
    ''');
    await db.execute('''
      CREATE INDEX idx_hourly_usage_date ON ${DatabaseConstants.tableHourlyUsageStats}(date);
    ''');
    await db.execute('''
      CREATE INDEX idx_hourly_usage_hour ON ${DatabaseConstants.tableHourlyUsageStats}(hour);
    ''');

    // v3 新增索引
    await db.execute('''
      CREATE INDEX idx_monitored_apps_enabled ON ${DatabaseConstants.tableMonitoredApps}(enabled);
    ''');
    await db.execute('''
      CREATE INDEX idx_time_periods_mode ON ${DatabaseConstants.tableTimePeriods}(mode);
    ''');
    await db.execute('''
      CREATE INDEX idx_time_periods_enabled ON ${DatabaseConstants.tableTimePeriods}(enabled);
    ''');
    await db.execute('''
      CREATE INDEX idx_continuous_session_date ON ${DatabaseConstants.tableContinuousSessions}(session_date);
    ''');
    await db.execute('''
      CREATE INDEX idx_continuous_session_active ON ${DatabaseConstants.tableContinuousSessions}(is_active);
    ''');

    // 性能优化：复合索引（v3.1 新增）
    // 用于按日期+包名查询使用记录
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_usage_date_package
      ON ${DatabaseConstants.tableAppUsageRecords}(date, package_name);
    ''');
    // 用于按时段查询统计数据
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_hourly_date_hour
      ON ${DatabaseConstants.tableHourlyUsageStats}(date, hour);
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2: 清除历史数据，创建小时级统计表
      print('[AppDatabase] Upgrading from v1 to v2...');

      // 清除旧数据
      await db.delete(DatabaseConstants.tableAppUsageRecords);
      await db.delete(DatabaseConstants.tableDailyStats);
      print('[AppDatabase] Cleared old data from app_usage_records and daily_stats');

      // 创建小时级使用统计表
      await db.execute('''
        CREATE TABLE ${DatabaseConstants.tableHourlyUsageStats} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          hour INTEGER NOT NULL,
          package_name TEXT NOT NULL,
          app_name TEXT,
          category TEXT,
          duration_seconds INTEGER DEFAULT 0,
          updated_at INTEGER NOT NULL,
          UNIQUE(date, hour, package_name) ON CONFLICT REPLACE
        );
      ''');

      // 创建索引
      await db.execute('''
        CREATE INDEX idx_hourly_usage_date ON ${DatabaseConstants.tableHourlyUsageStats}(date);
      ''');
      await db.execute('''
        CREATE INDEX idx_hourly_usage_hour ON ${DatabaseConstants.tableHourlyUsageStats}(hour);
      ''');

      print('[AppDatabase] Upgrade to v2 completed');
    }

    if (oldVersion < 3) {
      // v2 -> v3: 规则系统重构
      print('[AppDatabase] Upgrading from v2 to v3...');
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.transaction((txn) async {
        // 1. 创建新表
        await db.execute('''
          CREATE TABLE ${DatabaseConstants.tableMonitoredApps} (
            package_name TEXT PRIMARY KEY,
            app_name TEXT,
            daily_limit_minutes INTEGER,
            category TEXT,
            enabled INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE ${DatabaseConstants.tableTimePeriods} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mode TEXT NOT NULL,
            time_start TEXT NOT NULL,
            time_end TEXT NOT NULL,
            days TEXT NOT NULL,
            enabled INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE ${DatabaseConstants.tableContinuousSessions} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_date TEXT NOT NULL,
            start_time INTEGER NOT NULL,
            total_duration_seconds INTEGER DEFAULT 0,
            last_activity_time INTEGER,
            rest_end_time INTEGER,
            alerts_shown TEXT,
            is_active INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        // 2. 迁移数据
        // 2.1 time_block 规则 → time_periods 表
        final timeBlockRules = await db.query(
          DatabaseConstants.tableRules,
          where: 'rule_type = ?',
          whereArgs: ['time_block'],
        );
        for (final rule in timeBlockRules) {
          final timeStart = rule['time_start'] as String?;
          final timeEnd = rule['time_end'] as String?;
          if (timeStart == null || timeEnd == null) continue;

          await db.insert(DatabaseConstants.tableTimePeriods, {
            'mode': 'blocked',
            'time_start': timeStart,
            'time_end': timeEnd,
            'days': rule['target'] == 'weekday' ? '1,2,3,4,5' : '1,2,3,4,5,6,7',
            'enabled': rule['enabled'] ?? 1,
            'created_at': now,
          });
        }

        // 2.2 app_single 规则 → monitored_apps 表
        final appSingleRules = await db.query(
          DatabaseConstants.tableRules,
          where: 'rule_type = ?',
          whereArgs: ['app_single'],
        );
        for (final rule in appSingleRules) {
          final packageName = rule['target'] as String?;
          if (packageName == null) continue;

          // 尝试从 app_categories 表获取 app_name
          String? appName;
          final categoryInfo = await db.query(
            DatabaseConstants.tableAppCategories,
            where: 'package_name = ?',
            whereArgs: [packageName],
            limit: 1,
          );
          if (categoryInfo.isNotEmpty) {
            appName = categoryInfo.first['app_name'] as String?;
          }

          await db.insert(DatabaseConstants.tableMonitoredApps, {
            'package_name': packageName,
            'app_name': appName ?? packageName,
            'daily_limit_minutes': rule['weekday_limit'],
            'enabled': rule['enabled'] ?? 1,
            'created_at': now,
            'updated_at': now,
          });
        }

        // 2.3 app_category 规则 → 迁移该分类下所有 app 到 monitored_apps
        final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='${DatabaseConstants.tableAppCategories}'",
        );
        if (tableCheck.isNotEmpty) {
          final categoryRules = await db.query(
            DatabaseConstants.tableRules,
            where: 'rule_type = ?',
            whereArgs: ['app_category'],
          );
          for (final rule in categoryRules) {
            final category = rule['target'] as String?;
            if (category == null) continue;

            final appsInCategory = await db.query(
              DatabaseConstants.tableAppCategories,
              where: 'category = ?',
              whereArgs: [category],
            );

            for (final app in appsInCategory) {
              final packageName = app['package_name'] as String?;
              if (packageName == null) continue;

              // 检查是否已存在
              final existing = await db.query(
                DatabaseConstants.tableMonitoredApps,
                where: 'package_name = ?',
                whereArgs: [packageName],
              );
              if (existing.isNotEmpty) continue;

              await db.insert(DatabaseConstants.tableMonitoredApps, {
                'package_name': packageName,
                'app_name': app['app_name'],
                'daily_limit_minutes': rule['weekday_limit'],
                'category': category,
                'enabled': rule['enabled'] ?? 1,
                'created_at': now,
                'updated_at': now,
              });
            }
          }
        }

        // 3. 清理旧的规则类型（保留 total_time）
        await db.delete(
          DatabaseConstants.tableRules,
          where: 'rule_type IN (?, ?, ?)',
          whereArgs: ['time_block', 'app_single', 'app_category'],
        );

        // 4. 创建索引
        await db.execute('''
          CREATE INDEX idx_monitored_apps_enabled ON ${DatabaseConstants.tableMonitoredApps}(enabled);
        ''');
        await db.execute('''
          CREATE INDEX idx_time_periods_mode ON ${DatabaseConstants.tableTimePeriods}(mode);
        ''');
        await db.execute('''
          CREATE INDEX idx_time_periods_enabled ON ${DatabaseConstants.tableTimePeriods}(enabled);
        ''');
        await db.execute('''
          CREATE INDEX idx_continuous_session_date ON ${DatabaseConstants.tableContinuousSessions}(session_date);
        ''');
        await db.execute('''
          CREATE INDEX idx_continuous_session_active ON ${DatabaseConstants.tableContinuousSessions}(is_active);
        ''');
      });

      print('[AppDatabase] Upgrade to v3 completed');
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// 清空所有数据（用于测试）
  Future<void> clearAllTables() async {
    final db = await database;
    await db.delete(DatabaseConstants.tableAppUsageRecords);
    await db.delete(DatabaseConstants.tableRules);
    await db.delete(DatabaseConstants.tablePointsHistory);
    await db.delete(DatabaseConstants.tableCoupons);
    await db.delete(DatabaseConstants.tableDailyStats);
    await db.delete(DatabaseConstants.tableAppCategories);
    await db.delete(DatabaseConstants.tableHourlyUsageStats);
    await db.delete(DatabaseConstants.tableMonitoredApps);
    await db.delete(DatabaseConstants.tableTimePeriods);
    await db.delete(DatabaseConstants.tableContinuousSessions);
  }
}
