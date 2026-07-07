import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/egg_weekly_progress.dart';
import 'package:sqflite/sqflite.dart';

class EggState {
  final int stage;
  final EggStyle eggStyle;
  final int totalTaskCount;
  final int completedTaskCount;
  final String weekStart;
  final int highestStage;

  const EggState({
    this.stage = 0,
    this.eggStyle = EggStyle.princess,
    this.totalTaskCount = 0,
    this.completedTaskCount = 0,
    this.weekStart = '',
    this.highestStage = 0,
  });

  double get completionRate =>
      totalTaskCount == 0 ? 0.0 : completedTaskCount / totalTaskCount;

  EggState copyWith({
    int? stage,
    EggStyle? eggStyle,
    int? totalTaskCount,
    int? completedTaskCount,
    String? weekStart,
    int? highestStage,
  }) {
    return EggState(
      stage: stage ?? this.stage,
      eggStyle: eggStyle ?? this.eggStyle,
      totalTaskCount: totalTaskCount ?? this.totalTaskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      weekStart: weekStart ?? this.weekStart,
      highestStage: highestStage ?? this.highestStage,
    );
  }
}

class EggNotifier extends StateNotifier<EggState> {
  final EggWeeklyProgressDao _eggDao;
  final TaskCheckinDao _checkinDao;
  final TaskDefinitionDao _taskDefinitionDao;

  EggNotifier(this._eggDao, this._checkinDao, this._taskDefinitionDao)
      : super(const EggState());

  /// 计算本周一日期
  String _getWeekStart(DateTime date) {
    final weekday = date.weekday; // 1=Monday..7=Sunday
    final monday = date.subtract(Duration(days: weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 刷新周进度（从打卡记录计算）
  Future<void> refreshWeeklyProgress() async {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final tasks = await _taskDefinitionDao.getEnabled();

    // 计算本周应完成任务总天数 = 启用任务数 × 7
    final totalTaskCount = tasks.length * 7;

    // 计算本周已达标天数（每个任务每天 checkin >= minDailyCount 算达标）
    final monday = DateTime.parse(weekStart);
    final todayStr = _formatDate(now);
    int completedDays = 0;
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateStr = _formatDate(date);
      if (dateStr.compareTo(todayStr) > 0) break; // 跳过未来日期
      for (final task in tasks) {
        if (task.id == null) continue;
        final checkins = await _checkinDao.getByTaskAndDate(task.id!, dateStr);
        if (checkins.length >= task.minDailyCount) {
          completedDays++;
        }
      }
    }

    // 从 app_settings 读取当前风格
    EggStyle style = EggStyle.princess;
    try {
      final database = await AppDatabase.instance.database;
      final result = await database.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: ['egg_style'],
      );
      if (result.isNotEmpty) {
        style = EggStyle.fromCode(result.first['value'] as String);
      }
    } catch (_) {}

    // 计算阶段
    final rate = totalTaskCount == 0 ? 0.0 : completedDays / totalTaskCount;
    final stage = (rate * 5).floor().clamp(0, 4);

    // 获取上周最高阶段（如果有）
    final existing = await _eggDao.getByWeekStart(weekStart);
    final highestStage = existing != null
        ? (stage > existing.highestStage ? stage : existing.highestStage)
        : stage;

    // upsert 到数据库
    final progress = EggWeeklyProgress(
      weekStart: weekStart,
      totalTaskCount: totalTaskCount,
      completedTaskCount: completedDays,
      highestStage: highestStage,
      eggStyle: style,
    );
    await _eggDao.upsert(progress);

    state = EggState(
      stage: stage,
      eggStyle: style,
      totalTaskCount: totalTaskCount,
      completedTaskCount: completedDays,
      weekStart: weekStart,
      highestStage: highestStage,
    );
  }

  /// 切换蛋仔风格
  Future<void> changeStyle(EggStyle style) async {
    final weekStart = _getWeekStart(DateTime.now());
    await _eggDao.updateStyle(weekStart, style);

    // 写入 app_settings
    try {
      final database = await AppDatabase.instance.database;
      await database.insert(
        DatabaseConstants.tableAppSettings,
        {
          'key': 'egg_style',
          'value': style.code,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}

    state = state.copyWith(eggStyle: style);
  }
}

final eggProvider = StateNotifierProvider<EggNotifier, EggState>((ref) {
  final db = AppDatabase.instance;
  return EggNotifier(
    EggWeeklyProgressDao(db),
    TaskCheckinDao(db),
    TaskDefinitionDao(db),
  );
});
