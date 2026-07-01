import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:sqflite/sqflite.dart';

/// 家长密码存储仓库
/// 使用安全存储 + SHA256+salt加密
class ParentPasswordRepository {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyPasswordHash = 'parent_password_hash';
  static const _keySalt = 'parent_password_salt';
  static const _keyHasPassword = 'parent_has_password';

  // DB keys for native-side access (app_settings table)
  static const _dbKeyHash = 'parent_password_hash';
  static const _dbKeySalt = 'parent_password_salt';

  /// 检查是否已设置密码
  Future<bool> hasPassword() async {
    final hasPassword = await _storage.read(key: _keyHasPassword);
    return hasPassword == 'true';
  }

  /// 设置密码
  Future<void> setPassword(String password) async {
    // 生成随机salt
    final salt = _generateSalt();
    // 使用salt哈希密码
    final hash = _hashPassword(password, salt);

    await _storage.write(key: _keyPasswordHash, value: hash);
    await _storage.write(key: _keySalt, value: salt);
    await _storage.write(key: _keyHasPassword, value: 'true');

    // 双写入到 app_settings 表，供 Kotlin 端读取
    await _syncToDb({_dbKeyHash: hash, _dbKeySalt: salt});
  }

  /// 验证密码
  Future<bool> verifyPassword(String password) async {
    final storedHash = await _storage.read(key: _keyPasswordHash);
    final salt = await _storage.read(key: _keySalt);

    if (storedHash == null || salt == null) {
      return false;
    }

    final inputHash = _hashPassword(password, salt);
    return storedHash == inputHash;
  }

  /// 清除密码
  Future<void> clearPassword() async {
    await _storage.delete(key: _keyPasswordHash);
    await _storage.delete(key: _keySalt);
    await _storage.delete(key: _keyHasPassword);

    // 同步清除 DB 中的密码记录
    await _syncToDb({_dbKeyHash: '', _dbKeySalt: ''});
  }

  /// 迁移已有密码到 DB（应用初始化时调用）
  /// 如果 DB 中还没有密码记录，但从 FlutterSecureStorage 读取到密码，则写入 DB
  Future<void> migrateToDb() async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: [_dbKeyHash],
      );
      if (rows.isNotEmpty) return; // DB 中已有密码，无需迁移

      // 从 FlutterSecureStorage 读取
      final hash = await _storage.read(key: _keyPasswordHash);
      final salt = await _storage.read(key: _keySalt);
      if (hash != null && salt != null) {
        await _syncToDb({_dbKeyHash: hash, _dbKeySalt: salt});
      }
    } catch (_) {}
  }

  /// 将密码数据同步写入 app_settings 表，供原生侧读取
  Future<void> _syncToDb(Map<String, String> entries) async {
    try {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      for (final entry in entries.entries) {
        batch.insert(
          DatabaseConstants.tableAppSettings,
          {'key': entry.key, 'value': entry.value, 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// 生成随机salt
  String _generateSalt() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode(random + const Duration(days: 1).inSeconds.toString());
    return sha256.convert(bytes).toString().substring(0, 32);
  }

  /// 哈希密码
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }
}
