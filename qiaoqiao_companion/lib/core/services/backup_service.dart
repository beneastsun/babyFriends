import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// 备份服务
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  static const _backupDirName = 'qiaoqiao_backup';
  static const _maxBackupDays = 7;

  /// 获取备份目录
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/$_backupDirName');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 创建备份
  Future<File> createBackup(Map<String, dynamic> data) async {
    final backupDir = await _getBackupDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'backup_$timestamp.json';
    final file = File('${backupDir.path}/$fileName');

    final backupData = {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };

    await file.writeAsString(jsonEncode(backupData));

    // 清理旧备份
    await _cleanOldBackups();

    return file;
  }

  /// 获取所有备份
  Future<List<BackupInfo>> getBackups() async {
    final backupDir = await _getBackupDirectory();
    final files = await backupDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final backups = <BackupInfo>[];

    for (final file in files) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        backups.add(BackupInfo(
          file: file,
          timestamp: DateTime.parse(json['timestamp'] as String),
          version: json['version'] as int,
        ));
      } catch (e) {
        // 忽略无效的备份文件
      }
    }

    // 按时间倒序排列
    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return backups;
  }

  /// 恢复备份
  Future<Map<String, dynamic>?> restoreBackup(File file) async {
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json['data'] as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// 清理旧备份
  Future<void> _cleanOldBackups() async {
    final backups = await getBackups();
    if (backups.length > _maxBackupDays) {
      // 删除最旧的备份
      for (var i = _maxBackupDays; i < backups.length; i++) {
        await backups[i].file.delete();
      }
    }
  }

  /// 删除所有备份
  Future<void> deleteAllBackups() async {
    final backupDir = await _getBackupDirectory();
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
  }
}

/// 备份信息
class BackupInfo {
  final File file;
  final DateTime timestamp;
  final int version;

  const BackupInfo({
    required this.file,
    required this.timestamp,
    required this.version,
  });

  String get fileName => file.path.split('/').last;

  String get formattedDate {
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
  }
}

/// CSV导出服务
class CsvExportService {
  static final CsvExportService _instance = CsvExportService._internal();
  factory CsvExportService() => _instance;
  CsvExportService._internal();

  /// 导出使用记录为CSV
  Future<File> exportUsageRecords(List<Map<String, dynamic>> records) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${appDir.path}/usage_export_$timestamp.csv');

    final buffer = StringBuffer();

    // CSV头
    buffer.writeln('日期,应用名称,分类,使用时长(分钟)');

    // 数据行
    for (final record in records) {
      final date = record['date'] ?? '';
      final appName = record['app_name'] ?? '';
      final category = record['category'] ?? '';
      final minutes = record['minutes'] ?? 0;

      buffer.writeln('$date,$appName,$category,$minutes');
    }

    await file.writeAsString(buffer.toString());
    return file;
  }

  /// 导出积分记录为CSV
  Future<File> exportPointsRecords(List<Map<String, dynamic>> records) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${appDir.path}/points_export_$timestamp.csv');

    final buffer = StringBuffer();

    // CSV头
    buffer.writeln('日期,类型,数量,原因,余额');

    // 数据行
    for (final record in records) {
      final date = record['date'] ?? '';
      final type = record['type'] ?? '';
      final amount = record['amount'] ?? 0;
      final reason = record['reason'] ?? '';
      final balance = record['balance'] ?? 0;

      buffer.writeln('$date,$type,$amount,$reason,$balance');
    }

    await file.writeAsString(buffer.toString());
    return file;
  }
}
