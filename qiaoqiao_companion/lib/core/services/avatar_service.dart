import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 头像服务
/// 管理首页顶部头像图片的上传、存储和读取
class AvatarService {
  static const String _avatarPathKey = 'avatar_path';
  static const String _avatarFileName = 'avatar.jpg';

  final ImagePicker _picker = ImagePicker();
  SharedPreferences? _prefs;

  /// 获取 SharedPreferences 实例
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 获取头像文件路径
  Future<String?> getAvatarPath() async {
    final prefs = await _getPrefs();
    return prefs.getString(_avatarPathKey);
  }

  /// 获取头像文件
  Future<File?> getAvatarFile() async {
    final path = await getAvatarPath();
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    return file;
  }

  /// 检查是否有自定义头像
  Future<bool> hasCustomAvatar() async {
    final file = await getAvatarFile();
    return file != null;
  }

  /// 从相机拍照
  Future<File?> pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (image == null) return null;

      return await _saveImage(image);
    } catch (e) {
      print('从相机拍照失败: $e');
      return null;
    }
  }

  /// 从相册选择
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (image == null) return null;

      return await _saveImage(image);
    } catch (e) {
      print('从相册选择失败: $e');
      return null;
    }
  }

  /// 保存图片到应用目录
  Future<File> _saveImage(XFile image) async {
    final directory = await getApplicationDocumentsDirectory();
    final avatarPath = '${directory.path}/$_avatarFileName';

    // 删除旧头像
    final oldFile = File(avatarPath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }

    // 复制新图片
    final newFile = File(avatarPath);
    await newFile.writeAsBytes(await image.readAsBytes());

    // 保存路径到 SharedPreferences
    final prefs = await _getPrefs();
    await prefs.setString(_avatarPathKey, avatarPath);

    return newFile;
  }

  /// 删除自定义头像
  Future<void> deleteAvatar() async {
    final file = await getAvatarFile();
    if (file != null) {
      await file.delete();
    }

    final prefs = await _getPrefs();
    await prefs.remove(_avatarPathKey);
  }
}
