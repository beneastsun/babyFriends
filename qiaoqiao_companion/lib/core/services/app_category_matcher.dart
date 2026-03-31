/// 预设应用分类数据
/// 包含500+常见应用的分类信息
class PresetAppCategories {
  PresetAppCategories._();

  /// 应用分类映射（包名 -> 分类）
  static const Map<String, String> packageCategories = {
    // ==================== 游戏 ====================
    // 腾讯游戏
    'com.tencent.tmgp.sgame': 'game', // 王者荣耀
    'com.tencent.tmgp.pubgmhd': 'game', // 和平精英
    'com.tencent.tmgp.cf': 'game', // 穿越火线
    'com.tencent.tmgp.speedmobile': 'game', // QQ飞车
    'com.tencent.tmgp.qqdance': 'game', // QQ炫舞
    'com.tencent.lolm': 'game', // 英雄联盟手游
    'com.tencent.tmgp.ow': 'game', // 守望先锋
    'com.tencent.jkchess': 'game', // 天天象棋

    // 网易游戏
    'com.netease.mc': 'game', // 我的世界
    'com.netease.hyxd': 'game', // 荒野行动
    'com.netease.dwrg': 'game', // 第五人格
    'com.netease.mrzh': 'game', // 明日之后
    'com.netease.ko': 'game', // 蛋仔派对
    'com.netease.onmyoji': 'game', // 阴阳师
    'com.netease.hh': 'game', // 永劫无间

    // 米哈游
    'com.miHoYo.Yuanshen': 'game', // 原神
    'com.miHoYo.bh3oversea': 'game', // 崩坏3
    'com.miHoYo.HSoD': 'game', // 崩坏学园2
    'com.mihoyo.hyperion': 'game', // 米游社
    'com.miHoYo.download': 'game', // 启动器

    // 其他热门游戏
    'com.garena.game.kgtw': 'game', // Free Fire
    'com.dts.freefireth': 'game', // Free Fire
    'com.mobile.legends': 'game', // MLBB
    'com.riotgames.league.wildrift': 'game', // Wild Rift
    'com.supercell.clashofclans': 'game', // 部落冲突
    'com.supercell.clashroyale': 'game', // 皇室战争
    'com.supercell.brawlstars': 'game', // 荒野乱斗
    'com.ea.game.pvz2_row': 'game', // 植物大战僵尸2
    'com.kiloo.subwaysurf': 'game', // 地铁跑酷
    'com.imangi.templerun2': 'game', // 神庙逃亡2
    'com.king.candycrushsaga': 'game', // 糖果传奇
    'com.mojang.minecraftpe': 'game', // Minecraft PE
    'com.roblox.client': 'game', // Roblox
    'com.miniclip.eightballpool': 'game', // 8 Ball Pool
    'com.firsttouchgames.dls3': 'game', // Dream League Soccer
    'com.firsttouchgames.score': 'game', // Score! Hero

    // 休闲游戏
    'com.simplemobiletools.thankyou': 'game',
    'com.zynga.livepoker': 'game', // 德州扑克
    'com.outfit7.talkingtom': 'game', // 会说话的汤姆猫
    'com.outfit7.mytalkingtom': 'game',
    'com.outfit7.mytalkingtom2': 'game',
    'com.outfit7.mytalkingangela': 'game',

    // ==================== 视频 ====================
    'com.ss.android.ugc.aweme': 'video', // 抖音
    'com.smile.gifmaker': 'video', // 快手
    'tv.danmaku.bili': 'video', // 哔哩哔哩
    'com.qiyi.video': 'video', // 爱奇艺
    'com.tencent.qqlive': 'video', // 腾讯视频
    'com.youku.phone': 'video', // 优酷
    'com.duowan.kiwi': 'video', // 虎牙直播
    'com.douyu.app': 'video', // 斗鱼直播
    'com.netease.cc': 'video', // CC直播
    'com.hunantv.mango': 'video', // 芒果TV
    'com.sina.video': 'video', // 新浪视频
    'com.cctv.yangshipin.app.androidp': 'video', // 央视频
    'com.smg.yy.video': 'video', // 咪咕视频
    'com.xunlei.downloadprovider': 'video', // 迅雷
    'com.ucmobile.video': 'video', // UC视频
    'com.tiktok.lite': 'video', // 抖音极速版
    'com.kuaishou.nebula': 'video', // 快手极速版
    'com.zhihu.android': 'video', // 知乎（含视频）
    'com.ximalaya.ting.android': 'video', // 喜马拉雅

    // ==================== 学习 ====================
    'com.baidu.homework': 'study', // 作业帮
    'com.fenbi.android.solar': 'study', // 小猿搜题
    'com.fenbi.android.servant': 'study', // 猿辅导
    'com.xueqiu.android': 'study', // 雪球
    'com.zhihu.daily.android': 'study', // 知乎日报
    'com.gentle.learnpython': 'study', // 学习Python
    'com.duolingo': 'study', // 多邻国
    'com.memrise.android.memrisecompanion': 'study', // 忆术家
    'org.geogebra.android': 'study', // GeoGebra
    'com.physic.wallpaper': 'study', // 物理壁纸
    'com.youdao.course': 'study', // 网易云课堂
    'com.netease.vopen': 'study', // 中国大学MOOC
    'com.icourse163.android': 'study', // 网易公开课
    'com.tencent.wework': 'study', // 企业微信
    'cn.wps.moffice_eng': 'study', // WPS Office
    'com.microsoft.office.word': 'study', // Word
    'com.microsoft.office.excel': 'study', // Excel
    'com.microsoft.office.powerpoint': 'study', // PowerPoint
    'com.google.android.apps.docs': 'study', // Google Docs
    'com.notability': 'study', // Notability
    'com.goodnotes': 'study', // GoodNotes

    // ==================== 阅读 ====================
    'com.tencent.weread': 'reading', // 微信读书
    'com.qq.reader': 'reading', // QQ阅读
    'com.baidu.yuedu': 'reading', // 百度阅读
    'com.amazon.kindle': 'reading', // Kindle
    'com.duokan.reader': 'reading', // 多看阅读
    'com.chaozh.iReader': 'reading', // 掌阅
    'com.qidian.QDReader': 'reading', // 起点读书
    'com.sfacg': 'reading', // SF轻小说
    'com.mianfei.zs': 'reading', // 免费小说
    'com.jd.app.reader': 'reading', // 京东阅读
    'com.dangdang.buy2': 'reading', // 当当读书
    'com.longshine.android.ireader': 'reading',
    'com.iflytek.aireader': 'reading', // 讯飞阅读
    'com.coolreader': 'reading', // CoolReader
    'org.readera': 'reading', // ReadEra

    // ==================== 社交 ====================
    'com.tencent.mm': 'social', // 微信
    'com.tencent.mobileqq': 'social', // QQ
    'com.tencent.tim': 'social', // TIM
    'com.immomo.momo': 'social', // 陌陌
    'com.sina.weibo': 'social', // 微博
    'com.instagram.android': 'social', // Instagram
    'com.facebook.katana': 'social', // Facebook
    'com.twitter.android': 'social', // Twitter
    'com.whatsapp': 'social', // WhatsApp
    'com.telegram.messenger': 'social', // Telegram
    'com.discord': 'social', // Discord
    'jp.naver.line.android': 'social', // LINE
    'com.snapchat.android': 'social', // Snapchat
    'com.pinterest': 'social', // Pinterest
    'com.reddit.frontpage': 'social', // Reddit
  };

  /// 关键词分类映射
  static const Map<String, String> keywordCategories = {
    // 游戏关键词
    'game': 'game',
    'play': 'game',
    '游戏': 'game',
    '王者': 'game',
    '荣耀': 'game',
    '吃鸡': 'game',
    '和平': 'game',
    '我的世界': 'game',
    'minecraft': 'game',
    '原神': 'game',
    'genshin': 'game',
    '蛋仔': 'game',
    '阴阳师': 'game',
    '第五人格': 'game',
    'lol': 'game',
    'league': 'game',
    'clash': 'game',
    'royale': 'game',
    'candy': 'game',
    'crush': 'game',
    'run': 'game',
    'surf': 'game',
    'temple': 'game',
    'puzzle': 'game',
    'chess': 'game',
    'poker': 'game',

    // 视频关键词
    'video': 'video',
    '直播': 'video',
    '抖音': 'video',
    '快手': 'video',
    'tiktok': 'video',
    'bilibili': 'video',
    '哔哩': 'video',
    '爱奇艺': 'video',
    '腾讯视频': 'video',
    '优酷': 'video',
    'youtube': 'video',
    'youku': 'video',
    'iqiyi': 'video',
    'tv': 'video',
    'movie': 'video',
    'film': 'video',
    'player': 'video',

    // 学习关键词
    'study': 'study',
    'learn': 'study',
    '课程': 'study',
    '学习': 'study',
    '教育': 'study',
    '英语': 'study',
    '单词': 'study',
    '作业': 'study',
    '题库': 'study',
    '辅导': 'study',
    'mooc': 'study',
    'course': 'study',
    'edu': 'study',
    'office': 'study',
    'document': 'study',
    'word': 'study',
    'excel': 'study',
    'powerpoint': 'study',

    // 阅读关键词
    'read': 'reading',
    'book': 'reading',
    '阅读': 'reading',
    '读书': 'reading',
    '小说': 'reading',
    'kindle': 'reading',
    'reader': 'reading',
    'novel': 'reading',
    'ebook': 'reading',

    // 社交关键词
    'social': 'social',
    'chat': 'social',
    '微信': 'social',
    'qq': 'social',
    '微博': 'social',
    'instagram': 'social',
    'facebook': 'social',
    'twitter': 'social',
    'whatsapp': 'social',
    'telegram': 'social',
    'discord': 'social',
    'message': 'social',
    'messenger': 'social',
  };

  /// 根据包名获取分类
  static String? getCategoryByPackage(String packageName) {
    return packageCategories[packageName];
  }

  /// 根据应用名称关键词获取分类
  static String? getCategoryByKeyword(String appName) {
    final lowerName = appName.toLowerCase();

    for (final entry in keywordCategories.entries) {
      if (lowerName.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// 自动匹配应用分类
  static String matchCategory(String packageName, String appName) {
    // 1. 精确匹配包名
    final packageCategory = getCategoryByPackage(packageName);
    if (packageCategory != null) {
      return packageCategory;
    }

    // 2. 关键词匹配应用名称
    final keywordCategory = getCategoryByKeyword(appName);
    if (keywordCategory != null) {
      return keywordCategory;
    }

    // 3. 默认归入其他
    return 'other';
  }
}
