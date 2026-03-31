import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';

/// 应用分类步骤
class AppCategoryStep extends ConsumerStatefulWidget {
  const AppCategoryStep({super.key});

  @override
  ConsumerState<AppCategoryStep> createState() => _AppCategoryStepState();
}

class _AppCategoryStepState extends ConsumerState<AppCategoryStep> {
  final Map<String, String> _categories = {
    'game': '游戏',
    'video': '视频',
    'study': '学习',
    'reading': '阅读',
    'other': '其他',
  };

  // 模拟应用列表
  final List<Map<String, String>> _sampleApps = [
    {'name': '王者荣耀', 'package': 'com.tencent.tmgp.sgame', 'category': 'game'},
    {'name': '和平精英', 'package': 'com.tencent.tmgp.pubgmhd', 'category': 'game'},
    {'name': '我的世界', 'package': 'com.netease.mc', 'category': 'game'},
    {'name': '抖音', 'package': 'com.ss.android.ugc.aweme', 'category': 'video'},
    {'name': '哔哩哔哩', 'package': 'tv.danmaku.bili', 'category': 'video'},
    {'name': '爱奇艺', 'package': 'com.qiyi.video', 'category': 'video'},
    {'name': '作业帮', 'package': 'com.baidu.homework', 'category': 'study'},
    {'name': '小猿搜题', 'package': 'com.fenbi.android.solar', 'category': 'study'},
    {'name': '微信读书', 'package': 'com.tencent.weread', 'category': 'reading'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          // 标题
          Text(
            '应用分类',
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '为常用应用设置分类（可跳过）',
            style: AppTextStyles.body2,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),

          Expanded(
            child: ListView.builder(
              itemCount: _sampleApps.length,
              itemBuilder: (context, index) {
                final app = _sampleApps[index];
                return _buildAppCategoryCard(app);
              },
            ),
          ),

          // 分类说明
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.gameColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('游戏', style: AppTextStyles.caption),
                    SizedBox(width: AppSpacing.md),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.videoColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('视频', style: AppTextStyles.caption),
                    SizedBox(width: AppSpacing.md),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.studyColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('学习', style: AppTextStyles.caption),
                    SizedBox(width: AppSpacing.md),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.readingColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('阅读', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCategoryCard(Map<String, String> app) {
    final currentCategory = app['category'] ?? 'other';
    final color = AppTheme.getCategoryColor(currentCategory);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // 应用图标占位
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.apps, size: 24),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            // 应用名称
            Expanded(
              child: Text(
                app['name'] ?? '',
                style: AppTextStyles.body1,
              ),
            ),
            // 分类选择器
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color),
              ),
              child: Text(
                _categories[currentCategory] ?? '其他',
                style: AppTextStyles.caption.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
