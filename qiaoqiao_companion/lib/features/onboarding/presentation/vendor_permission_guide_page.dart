import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/platform/platform.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 厂商权限引导页面
/// 针对不同厂商ROM显示自启动权限设置引导
class VendorPermissionGuidePage extends StatefulWidget {
  final VoidCallback? onComplete;

  const VendorPermissionGuidePage({super.key, this.onComplete});

  @override
  State<VendorPermissionGuidePage> createState() => _VendorPermissionGuidePageState();
}

class _VendorPermissionGuidePageState extends State<VendorPermissionGuidePage> {
  String _romType = 'OTHER';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRomInfo();
  }

  Future<void> _loadRomInfo() async {
    final romType = await MonitorService.getRomType();
    setState(() {
      _romType = romType;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('设置权限'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              '完成最后一步设置',
              style: AppTextStyles.heading1,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '为了确保纹纹小伙伴能正常工作，请完成以下设置',
              style: AppTextStyles.body2,
            ),
            SizedBox(height: AppSpacing.xl),

            // ROM特定引导卡片
            _buildRomGuideCard(),

            SizedBox(height: AppSpacing.xl),

            // 步骤说明
            _buildStepsList(),

            SizedBox(height: AppSpacing.xxl),

            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// 构建ROM引导卡片
  Widget _buildRomGuideCard() {
    final vendorInfo = _getVendorInfo(_romType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // 厂商图标和名称
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: vendorInfo.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: Text(
                  vendorInfo.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              vendorInfo.name,
              style: AppTextStyles.heading2,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              vendorInfo.description,
              style: AppTextStyles.body2,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建步骤列表
  Widget _buildStepsList() {
    final steps = _getGuideSteps(_romType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '操作步骤',
          style: AppTextStyles.heading3,
        ),
        SizedBox(height: AppSpacing.md),
        ...steps.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entry.value,
                      style: AppTextStyles.body1,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Column(
      children: [
        AppButtonPrimary(
          onPressed: _openSettings,
          isFullWidth: true,
          icon: const Icon(Icons.settings),
          child: Text('打开设置'),
        ),
        SizedBox(height: AppSpacing.md),
        AppButtonSecondary(
          onPressed: widget.onComplete,
          isFullWidth: true,
          child: Text('我已完成设置'),
        ),
      ],
    );
  }

  /// 打开设置
  Future<void> _openSettings() async {
    final success = await MonitorService.openAutoStartSettings();
    if (!success && mounted) {
      // 如果打开失败，显示手动操作指南
      _showManualGuideDialog();
    }
  }

  /// 显示手动操作指南对话框
  void _showManualGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('手动设置指南'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '无法自动打开设置页面，请按以下步骤手动操作：',
                style: AppTextStyles.body1,
              ),
              SizedBox(height: AppSpacing.md),
              Text('1. 打开"设置"应用'),
              Text('2. 找到"应用管理"或"应用列表"'),
              Text('3. 找到"纹纹小伙伴"应用'),
              Text('4. 进入"权限"或"自启动"设置'),
              Text('5. 开启"自启动"或"后台运行"权限'),
              SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '不同手机型号的设置路径可能略有不同',
                        style: TextStyle(color: AppColors.info, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButtonGhost(
            onPressed: () => Navigator.pop(context),
            child: Text('我知道了'),
          ),
          AppButtonPrimary(
            onPressed: () {
              Navigator.pop(context);
              MonitorService.openAppDetailSettings();
            },
            child: Text('打开应用详情'),
          ),
        ],
      ),
    );
  }

  /// 获取厂商信息
  _VendorInfo _getVendorInfo(String romType) {
    switch (romType) {
      case 'MIUI':
        return _VendorInfo(
          name: '小米 MIUI',
          emoji: '📱',
          color: AppColors.primary,
          description: '需要在安全中心中开启自启动权限',
        );
      case 'EMUI':
      case 'HARMONY':
        return _VendorInfo(
          name: '华为',
          emoji: '🔴',
          color: Colors.red,
          description: '需要在手机管家中开启自启动权限',
        );
      case 'COLOR_OS':
        return _VendorInfo(
          name: 'OPPO ColorOS',
          emoji: '🟢',
          color: Colors.green,
          description: '需要在安全中心中开启自启动权限',
        );
      case 'FUNTOUCH_OS':
      case 'ORIGIN_OS':
        return _VendorInfo(
          name: 'vivo',
          emoji: '🔵',
          color: Colors.blue,
          description: '需要在权限管理中开启自启动权限',
        );
      case 'ONE_UI':
        return _VendorInfo(
          name: '三星 One UI',
          emoji: '🌟',
          color: Colors.indigo,
          description: '需要在设置中关闭电池优化',
        );
      case 'FLYME':
        return _VendorInfo(
          name: '魅族 Flyme',
          emoji: '🦋',
          color: Colors.cyan,
          description: '需要在安全中心中开启自启动权限',
        );
      default:
        return _VendorInfo(
          name: 'Android 设备',
          emoji: '🤖',
          color: Colors.grey,
          description: '建议在设置中将应用加入白名单',
        );
    }
  }

  /// 获取引导步骤
  List<String> _getGuideSteps(String romType) {
    switch (romType) {
      case 'MIUI':
        return [
          '点击"打开设置"进入安全中心',
          '找到"自启动管理"',
          '找到"纹纹小伙伴"并开启开关',
          '返回继续使用应用',
        ];
      case 'EMUI':
      case 'HARMONY':
        return [
          '点击"打开设置"进入手机管家',
          '找到"应用启动管理"',
          '找到"纹纹小伙伴"',
          '关闭"自动管理"，开启"手动管理"中的所有选项',
          '返回继续使用应用',
        ];
      case 'COLOR_OS':
        return [
          '点击"打开设置"进入安全中心',
          '找到"自启动管理"',
          '找到"纹纹小伙伴"并开启开关',
          '返回继续使用应用',
        ];
      case 'FUNTOUCH_OS':
      case 'ORIGIN_OS':
        return [
          '点击"打开设置"进入权限管理',
          '找到"自启动"',
          '找到"纹纹小伙伴"并开启开关',
          '返回继续使用应用',
        ];
      case 'ONE_UI':
        return [
          '点击"打开设置"进入应用信息',
          '找到"电池"',
          '选择"无限制"',
          '返回继续使用应用',
        ];
      case 'FLYME':
        return [
          '点击"打开设置"进入安全中心',
          '找到"自启动管理"',
          '找到"纹纹小伙伴"并开启开关',
          '返回继续使用应用',
        ];
      default:
        return [
          '点击"打开设置"进入应用信息',
          '找到"电池"或"后台管理"选项',
          '将"纹纹小伙伴"加入白名单',
          '返回继续使用应用',
        ];
    }
  }
}

class _VendorInfo {
  final String name;
  final String emoji;
  final Color color;
  final String description;

  _VendorInfo({
    required this.name,
    required this.emoji,
    required this.color,
    required this.description,
  });
}
