/// 禁用app提醒记录
class ForbiddenAppRecord {
  final String packageName;
  final int reminderCount;       // 已关闭的提醒次数
  final DateTime? lastDismissedAt; // 上次关闭时间
  final DateTime? lastShownAt;     // 上次显示时间

  const ForbiddenAppRecord({
    required this.packageName,
    this.reminderCount = 0,
    this.lastDismissedAt,
    this.lastShownAt,
  });

  ForbiddenAppRecord copyWith({
    String? packageName,
    int? reminderCount,
    DateTime? lastDismissedAt,
    DateTime? lastShownAt,
  }) {
    return ForbiddenAppRecord(
      packageName: packageName ?? this.packageName,
      reminderCount: reminderCount ?? this.reminderCount,
      lastDismissedAt: lastDismissedAt ?? this.lastDismissedAt,
      lastShownAt: lastShownAt ?? this.lastShownAt,
    );
  }
}

/// 禁用app提醒跟踪器
///
/// 跟踪每个禁用app的提醒状态，实现递进式提醒逻辑：
/// - 第1次关闭后等2分钟
/// - 第2次关闭后等1分钟
/// - 第3次关闭后等30秒
/// - 第4次及以后等待1分钟后可关闭
class ForbiddenAppTracker {
  /// 按包名存储的提醒记录
  final Map<String, ForbiddenAppRecord> _records = {};

  /// 是否应该显示提醒（检查间隔时间）
  ///
  /// 如果是第一次，立即返回true
  /// 如果之前关闭过，检查是否已过等待间隔
  bool shouldShowReminder(String packageName) {
    final record = _records[packageName];
    if (record == null) return true;
    if (record.lastDismissedAt == null) return true;

    final interval = getReminderInterval(record.reminderCount);
    if (interval == Duration.zero) return true; // 第4次+立即显示

    final elapsed = DateTime.now().difference(record.lastDismissedAt!);
    return elapsed >= interval;
  }

  /// 记录overlay已显示（在显示时调用）
  void recordShown(String packageName) {
    final record = _records[packageName];
    if (record == null) {
      _records[packageName] = ForbiddenAppRecord(
        packageName: packageName,
        lastShownAt: DateTime.now(),
      );
    } else {
      _records[packageName] = record.copyWith(
        lastShownAt: DateTime.now(),
      );
    }
  }

  /// 记录用户关闭了提醒（从Android回调）
  void recordDismissal(String packageName) {
    final record = _records[packageName];
    if (record == null) return;

    _records[packageName] = record.copyWith(
      reminderCount: record.reminderCount + 1,
      lastDismissedAt: DateTime.now(),
    );
  }

  /// 获取当前提醒次数（已关闭的次数）
  int getReminderCount(String packageName) {
    return _records[packageName]?.reminderCount ?? 0;
  }

  /// 是否可以关闭（始终可关闭，但第4次后需等待1分钟）
  ///
  /// 注意：此方法仅表示是否有关闭按钮，实际关闭能力由 canDismissNow 决定
  bool isDismissible(String packageName) {
    return true; // 始终可关闭，但第4次后需等待1分钟
  }

  /// 获取提醒间隔时间
  ///
  /// closedCount是已关闭的次数：
  /// - 0: 首次显示，立即
  /// - 1: 第1次关闭后等2分钟
  /// - 2: 第2次关闭后等1分钟
  /// - 3: 第3次关闭后等30秒
  /// - 4+: 第4次+立即显示（1分钟后可关闭）
  Duration getReminderInterval(int closedCount) {
    switch (closedCount) {
      case 0:
        return Duration.zero; // 首次立即显示
      case 1:
        return const Duration(minutes: 2);
      case 2:
        return const Duration(minutes: 1);
      case 3:
        return const Duration(seconds: 30);
      default:
        return Duration.zero; // 第4次+立即显示
    }
  }

  /// 检查是否可以立即关闭（第4次后需等待1分钟）
  bool canDismissNow(String packageName) {
    final count = getReminderCount(packageName);
    if (count < 3) return true; // 前3次立即关闭

    // 第4次+：检查距离上次显示是否已过1分钟
    final record = _records[packageName];
    final lastShown = record?.lastShownAt;
    if (lastShown == null) return true;

    final elapsed = DateTime.now().difference(lastShown);
    return elapsed >= const Duration(minutes: 1);
  }

  /// 获取解锁剩余秒数
  int getDismissRemainingSeconds(String packageName) {
    final count = getReminderCount(packageName);
    if (count < 3) return 0;

    final record = _records[packageName];
    final lastShown = record?.lastShownAt;
    if (lastShown == null) return 0;

    final elapsed = DateTime.now().difference(lastShown);
    final remaining = const Duration(minutes: 1) - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  /// 重置所有记录（午夜调用）
  void resetAll() {
    _records.clear();
  }

  /// 重置单个app记录
  void resetForApp(String packageName) {
    _records.remove(packageName);
  }

  /// 获取所有记录（用于调试）
  Map<String, ForbiddenAppRecord> get allRecords => Map.unmodifiable(_records);
}
