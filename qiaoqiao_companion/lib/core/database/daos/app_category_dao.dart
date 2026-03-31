import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 应用分类 DAO
class AppCategoryDao {
  final AppDatabase _database;

  AppCategoryDao(this._database);

  Future<int> insert(AppCategoryRecord record) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableAppCategories,
      record.toMap(),
    );
  }

  Future<int> insertOrUpdate(AppCategoryRecord record) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableAppCategories,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppCategoryRecord?> getByPackageName(String packageName) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableAppCategories,
      where: 'package_name = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppCategoryRecord.fromMap(maps.first);
  }

  Future<List<AppCategoryRecord>> getAll() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableAppCategories,
      orderBy: 'app_name ASC',
    );
    return maps.map((map) => AppCategoryRecord.fromMap(map)).toList();
  }

  Future<List<AppCategoryRecord>> getByCategory(AppCategory category) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableAppCategories,
      where: 'category = ?',
      whereArgs: [category.code],
      orderBy: 'app_name ASC',
    );
    return maps.map((map) => AppCategoryRecord.fromMap(map)).toList();
  }

  Future<int> update(AppCategoryRecord record) async {
    final db = await _database.database;
    return await db.update(
      DatabaseConstants.tableAppCategories,
      record.toMap(),
      where: 'package_name = ?',
      whereArgs: [record.packageName],
    );
  }

  /// 设置应用分类
  Future<void> setCategory(
    String packageName,
    String? appName,
    AppCategory category, {
    bool isCustom = true,
  }) async {
    final record = AppCategoryRecord(
      packageName: packageName,
      appName: appName,
      category: category,
      isCustom: isCustom,
    );
    await insertOrUpdate(record);
  }

  Future<int> delete(String packageName) async {
    final db = await _database.database;
    return await db.delete(
      DatabaseConstants.tableAppCategories,
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tableAppCategories);
  }

  /// 批量导入预设分类
  Future<void> importPresets(Map<String, AppCategory> presets) async {
    for (final entry in presets.entries) {
      await setCategory(
        entry.key,
        null,
        entry.value,
        isCustom: false,
      );
    }
  }
}

/// 预设应用分类数据库（主流应用）
class PresetAppCategories {
  static const Map<String, AppCategory> presets = {
    // 游戏类
    'com.mojang.minecraftpe': AppCategory.game,
    'com.tencent.tmgp.sgame': AppCategory.game,
    'com.tencent.tmgp.pubgmhd': AppCategory.game,
    'com.tencent.king glory': AppCategory.game,
    'com.tencent.tmgp.cf': AppCategory.game,
    'com.netease.ko': AppCategory.game,
    'com.supercell.clashofclans': AppCategory.game,
    'com.supercell.clashroyale': AppCategory.game,
    'com.roblox.client': AppCategory.game,
    'com.ea.games.nfs13_row': AppCategory.game,

    // 视频类
    'com.ss.android.ugc.aweme': AppCategory.video, // 抖音
    'com.smile.gifmaker': AppCategory.video, // 快手
    'tv.danmaku.bili': AppCategory.video, // B站
    'com.qiyi.video': AppCategory.video, // 爱奇艺
    'com.youku.phone': AppCategory.video, // 优酷
    'com.tencent.qqlive': AppCategory.video, // 腾讯视频
    'com.netease.cloudmusic': AppCategory.video, // 网易云音乐
    'com.kugou.android': AppCategory.video, // 酷狗音乐
    'com.tencent.qqmusic': AppCategory.video, // QQ音乐

    // 学习类
    'com.xiaomi.shop': AppCategory.study, // 小米有品 (标记为学习)
    'com.baidu.homework': AppCategory.study, // 作业帮
    'com.yuanfudao': AppCategory.study, // 猿辅导
    'com.zuoyebang.app': AppCategory.study, // 作业帮
    'com.icourse163': AppCategory.study, // 中国大学MOOC
    'cn.com.openmooc': AppCategory.study, // 慕课网
    'com.duolingo': AppCategory.study, // 多邻国
    'com.eusoft.eudic': AppCategory.study, // 欧路词典

    // 阅读类
    'com.weread': AppCategory.reading, // 微信读书
    'com.chaoxing.mobile': AppCategory.reading, // 超星学习通
    'com.sdui.reader': AppCategory.reading, // 阅读软件
  };
}
