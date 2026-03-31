/// 限制来源枚举
enum LimitSource {
  singleApp('single_app', '单应用规则'),
  category('category', '分类规则'),
  total('total', '总时间规则'),
  none('none', '无限制');

  final String code;
  final String label;

  const LimitSource(this.code, this.label);

  static LimitSource fromCode(String code) {
    return LimitSource.values.firstWhere(
      (e) => e.code == code,
      orElse: () => LimitSource.none,
    );
  }
}
