import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// 家长密码存储仓库
/// 使用安全存储 + SHA256+salt加密
class ParentPasswordRepository {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyPasswordHash = 'parent_password_hash';
  static const _keySalt = 'parent_password_salt';
  static const _keyHasPassword = 'parent_has_password';

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
