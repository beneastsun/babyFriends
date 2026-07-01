from PIL import Image, ImageDraw, ImageFont
import os

# 输出目录
output_dir = r"D:\Developfile\baby-friends\qiaoqiao_companion\mockup\screens"
os.makedirs(output_dir, exist_ok=True)

# 配色方案
COLORS = {
    'primary': (236, 139, 159),      # #EC8B9F
    'secondary': (197, 179, 230),    # #C5B3E6
    'background': (250, 249, 248),   # #FAF9F8
    'surface': (255, 255, 255),      # #FFFFFF
    'text_primary': (29, 29, 31),    # #1D1D1F
    'text_secondary': (134, 134, 139), # #86868B
    'game_bg': (255, 229, 240),      # #FFE5F0
    'video_bg': (232, 228, 255),     # #E8E4FF
    'study_bg': (232, 255, 248),     # #E8FFF8
    'points_start': (255, 217, 119), # #FFD977
    'points_end': (255, 179, 71),    # #FFB347
    'success': (127, 219, 202),      # #7FDBCA
}

# 屏幕尺寸
WIDTH = 375
HEIGHT = 812

def create_gradient(draw, x0, y0, x1, y1, color_start, color_end):
    """创建渐变"""
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps):
        ratio = i / steps
        r = int(color_start[0] * (1 - ratio) + color_end[0] * ratio)
        g = int(color_start[1] * (1 - ratio) + color_end[1] * ratio)
        b = int(color_start[2] * (1 - ratio) + color_end[2] * ratio)
        if x0 == x1:  # 垂直渐变
            draw.line([(x0, y0 + i), (x1, y0 + i)], fill=(r, g, b))
        else:  # 水平渐变
            draw.line([(x0 + i, y0), (x0 + i, y1)], fill=(r, g, b))

def rounded_rectangle(draw, coords, radius, fill):
    """绘制圆角矩形"""
    x0, y0, x1, y1 = coords
    # 确保坐标正确
    if x0 > x1:
        x0, x1 = x1, x0
    if y0 > y1:
        y0, y1 = y1, y0

    # 主矩形（避开圆角区域）
    if x0 + radius <= x1 - radius:
        draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    if y0 + radius <= y1 - radius:
        draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)

    # 四个圆角
    r = min(radius, (x1 - x0) // 2, (y1 - y0) // 2)
    if r > 0:
        draw.pieslice([x0, y0, x0 + r * 2, y0 + r * 2], 180, 270, fill=fill)
        draw.pieslice([x1 - r * 2, y0, x1, y0 + r * 2], 270, 360, fill=fill)
        draw.pieslice([x0, y1 - r * 2, x0 + r * 2, y1], 90, 180, fill=fill)
        draw.pieslice([x1 - r * 2, y1 - r * 2, x1, y1], 0, 90, fill=fill)

def draw_text_centered(draw, text, x, y, font, fill):
    """居中绘制文本"""
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    draw.text((x - text_width // 2, y), text, font=font, fill=fill)

def draw_header(draw, title, show_notif=True):
    """绘制头部"""
    # 标题
    try:
        title_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 28)
    except:
        title_font = ImageFont.load_default()
    draw.text((20, 60), title, font=title_font, fill=COLORS['text_primary'])

    if show_notif:
        # 通知图标
        rounded_rectangle(draw, [311, 52, 355, 96], 14, COLORS['surface'])
        # 铃铛图标
        draw.ellipse([328, 65, 338, 72], fill=COLORS['text_primary'])
        draw.arc([325, 72, 341, 82], 0, 180, fill=COLORS['text_primary'], width=2)
        draw.line([(333, 82), (333, 86)], fill=COLORS['text_primary'], width=2)

def draw_avatar_card(draw):
    """绘制头像卡片"""
    # 渐变背景
    for y in range(120, 220):
        ratio = (y - 120) / 100
        r = int(COLORS['primary'][0] * (1 - ratio) + COLORS['secondary'][0] * ratio)
        g = int(COLORS['primary'][1] * (1 - ratio) + COLORS['secondary'][1] * ratio)
        b = int(COLORS['primary'][2] * (1 - ratio) + COLORS['secondary'][2] * ratio)
        draw.rectangle([20, y, 355, y + 1], fill=(r, g, b))

    # 头像
    rounded_rectangle(draw, [44, 144, 124, 224], 24, (255, 255, 255))
    try:
        emoji_font = ImageFont.truetype("C:\\Windows\\Fonts\\seguiemj.ttf", 48)
    except:
        emoji_font = ImageFont.load_default()
    draw_text_centered(draw, "🌸", 84, 166, emoji_font, COLORS['primary'])

    # 名字和状态
    try:
        name_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 22)
        desc_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 14)
        badge_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 13)
    except:
        name_font = ImageFont.load_default()
        desc_font = ImageFont.load_default()
        badge_font = ImageFont.load_default()

    draw.text([144, 162], "纹纹", font=name_font, fill=(255, 255, 255))
    draw.text([144, 192], "新的一天开始啦～", font=desc_font, fill=(255, 255, 255))

    # 状态徽章
    rounded_rectangle(draw, [144, 212, 236, 236], 12, (255, 255, 255, 60))
    draw.ellipse([152, 220, 160, 228], fill=COLORS['success'])
    draw.text([168, 220], "状态良好", font=badge_font, fill=(255, 255, 255))

def draw_usage_card(draw):
    """绘制使用卡片"""
    rounded_rectangle(draw, [20, 240, 355, 380], 24, COLORS['surface'])

    try:
        header_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 18)
        time_font = ImageFont.truetype("C:\\Windows\\Fonts\\arialbd.ttf", 56)
        unit_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 16)
        small_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 12)
    except:
        header_font = ImageFont.load_default()
        time_font = ImageFont.load_default()
        unit_font = ImageFont.load_default()
        small_font = ImageFont.load_default()

    draw.text([44, 268], "今日使用", font=header_font, fill=COLORS['text_primary'])
    draw.text([310, 270], "更新于 刚刚", font=small_font, fill=COLORS['text_secondary'])

    # 时间数字
    draw.text([44, 310], "65", font=time_font, fill=COLORS['primary'])
    draw.text([108, 340], "分钟 / 120分钟", font=unit_font, fill=COLORS['text_secondary'])

    # 进度条
    rounded_rectangle(draw, [44, 368, 331, 376], 4, COLORS['background'])
    rounded_rectangle(draw, [44, 368, 220, 376], 4, COLORS['primary'])

    # 进度标签
    draw.text([44, 384], "已用 54%", font=small_font, fill=COLORS['text_secondary'])
    draw.text([280, 384], "还剩 55分钟", font=small_font, fill=COLORS['text_secondary'])

def draw_app_list(draw):
    """绘制应用列表"""
    try:
        title_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 18)
        name_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 15)
        time_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 13)
        badge_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 11)
    except:
        title_font = ImageFont.load_default()
        name_font = ImageFont.load_default()
        time_font = ImageFont.load_default()
        badge_font = ImageFont.load_default()

    draw.text([20, 410], "使用排行", font=title_font, fill=COLORS['text_primary'])

    apps = [
        ("🎮", "我的世界", "25 分钟", COLORS['game_bg'], COLORS['primary'], "游戏"),
        ("📺", "哔哩哔哩", "18 分钟", COLORS['video_bg'], COLORS['secondary'], "视频"),
        ("📚", "洪恩识字", "22 分钟", COLORS['study_bg'], COLORS['success'], "学习"),
    ]

    y_start = 450
    for i, (icon, name, time, bg_color, text_color, badge) in enumerate(apps):
        y = y_start + i * 76

        # 卡片背景
        rounded_rectangle(draw, [20, y, 355, y + 68], 20, COLORS['surface'])

        # 图标背景
        rounded_rectangle(draw, [36, y + 8, 88, y + 60], 14, bg_color)
        try:
            emoji_font = ImageFont.truetype("C:\\Windows\\Fonts\\seguiemj.ttf", 32)
        except:
            emoji_font = ImageFont.load_default()
        draw_text_centered(draw, icon, 62, y + 18, emoji_font, (0, 0, 0))

        # 应用信息
        draw.text([100, y + 16], name, font=name_font, fill=COLORS['text_primary'])
        draw.text([100, y + 40], time, font=time_font, fill=COLORS['text_secondary'])

        # 徽章
        badge_width = len(badge) * 8 + 16
        rounded_rectangle(draw, [355 - badge_width - 12, y + 24, 343, y + 44], 8, bg_color)
        draw.text([355 - badge_width - 8, y + 27], badge, font=badge_font, fill=text_color)

def draw_bottom_nav(draw, active=0):
    """绘制底部导航"""
    # 毛玻璃背景
    nav_bg = Image.new('RGBA', (WIDTH, 85), (255, 255, 255, 245))
    draw.bitmap((0, HEIGHT - 85), nav_bg)

    icons = ["🏠", "📋", "👤"]
    labels = ["首页", "规则", "我的"]

    for i, (icon, label) in enumerate(zip(icons, labels)):
        x = 62 + i * 125
        y = HEIGHT - 65

        if i == active:
            # 激活状态背景
            rounded_rectangle(draw, [x - 22, y - 8, x + 22, y + 28], 12, (COLORS['primary'][0], COLORS['primary'][1], COLORS['primary'][2], 30))

        try:
            emoji_font = ImageFont.truetype("C:\\Windows\\Fonts\\seguiemj.ttf", 26)
            label_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 11)
        except:
            emoji_font = ImageFont.load_default()
            label_font = ImageFont.load_default()

        draw_text_centered(draw, icon, x, y, emoji_font, COLORS['text_primary'] if i == active else COLORS['text_secondary'])
        draw_text_centered(draw, label, x, y + 26, label_font, COLORS['primary'] if i == active else COLORS['text_secondary'])

# 创建首页
print("Creating home screen...")
img = Image.new('RGB', (WIDTH, HEIGHT), COLORS['background'])
draw = ImageDraw.Draw(img)

draw_header(draw, "纹纹小伙伴")
draw_avatar_card(draw)
draw_usage_card(draw)
draw_app_list(draw)
draw_bottom_nav(draw, active=0)

img.save(os.path.join(output_dir, "01_home.png"))
print("[OK] Home screen saved")

# 创建规则页
print("Creating rules screen...")
img = Image.new('RGB', (WIDTH, HEIGHT), COLORS['background'])
draw = ImageDraw.Draw(img)

draw_header(draw, "使用规则")

try:
    title_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 18)
    name_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 15)
    desc_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 13)
except:
    title_font = ImageFont.load_default()
    name_font = ImageFont.load_default()
    desc_font = ImageFont.load_default()

draw.text([20, 410], "时间规则", font=title_font, fill=COLORS['text_primary'])

rules = [
    ("⏰", "每日限额", "每天最多使用 2 小时", COLORS['game_bg'], True),
    ("🌙", "睡眠时间", "21:00 - 07:00 禁止使用", COLORS['game_bg'], True),
    ("📖", "学习时间", "16:00 - 18:00 仅学习应用", (255, 249, 232), False),
]

y_start = 450
for i, (icon, title, desc, bg_color, is_on) in enumerate(rules):
    y = y_start + i * 76
    rounded_rectangle(draw, [20, y, 355, y + 68], 20, COLORS['surface'])

    rounded_rectangle(draw, [36, y + 10, 84, y + 58], 16, bg_color)
    try:
        emoji_font = ImageFont.truetype("C:\\Windows\\Fonts\\seguiemj.ttf", 28)
    except:
        emoji_font = ImageFont.load_default()
    draw_text_centered(draw, icon, 60, y + 22, emoji_font, (0, 0, 0))

    draw.text([96, y + 14], title, font=name_font, fill=COLORS['text_primary'])
    draw.text([96, y + 38], desc, font=desc_font, fill=COLORS['text_secondary'])

    # 开关
    toggle_color = COLORS['primary'] if is_on else COLORS['text_secondary']
    toggle_x1, toggle_y1 = 310, y + 20
    toggle_x2, toggle_y2 = 342, y + 48
    rounded_rectangle(draw, [toggle_x1, toggle_y1, toggle_x2, toggle_y2], 14, toggle_color)
    if is_on:
        rounded_rectangle(draw, [330, y + 24, 338, y + 44], 12, (255, 255, 255))
    else:
        rounded_rectangle(draw, [314, y + 24, 322, y + 44], 12, (255, 255, 255))

draw.text([20, 680], "应用分类", font=title_font, fill=COLORS['text_primary'])

cat_rules = [
    ("🎮", "游戏类", "每天最多 1 小时"),
    ("📺", "视频类", "每天最多 45 分钟"),
]

y_cat = 720
for i, (icon, title, desc) in enumerate(cat_rules):
    y = y_cat + i * 76
    rounded_rectangle(draw, [20, y, 355, y + 68], 20, COLORS['surface'])

    rounded_rectangle(draw, [36, y + 10, 84, y + 58], 16, COLORS['video_bg'])
    draw_text_centered(draw, icon, 60, y + 22, emoji_font, (0, 0, 0))

    draw.text([96, y + 14], title, font=name_font, fill=COLORS['text_primary'])
    draw.text([96, y + 38], desc, font=desc_font, fill=COLORS['text_secondary'])

    rounded_rectangle(draw, [310, y + 20, 342, y + 48], 14, COLORS['primary'])
    rounded_rectangle(draw, [330, y + 24, 338, y + 44], 12, (255, 255, 255))

draw_bottom_nav(draw, active=1)
img.save(os.path.join(output_dir, "02_rules.png"))
print("[OK] Rules screen saved")

# 创建设置页
print("Creating settings screen...")
img = Image.new('RGB', (WIDTH, HEIGHT), COLORS['background'])
draw = ImageDraw.Draw(img)

draw_header(draw, "设置", show_notif=False)

try:
    item_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 15)
    value_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 13)
except:
    item_font = ImageFont.load_default()
    value_font = ImageFont.load_default()

settings = [
    ("🎨", "主题风格", "樱花粉", COLORS['game_bg']),
    ("🔔", "提醒通知", "已开启", COLORS['video_bg']),
    ("🔊", "提醒音效", "轻柔", COLORS['study_bg']),
    ("💾", "数据备份", "上次: 今天 03:00", (255, 249, 232)),
    ("👨‍👩‍👧", "家长模式", "已设置密码", COLORS['game_bg']),
    ("ℹ️", "关于纹纹", "版本 1.0.0", COLORS['video_bg']),
    ("💌", "反馈建议", "帮助我们改进", COLORS['study_bg']),
]

y_start = 130
for i, (icon, title, value, bg_color) in enumerate(settings):
    y = y_start + i * 64
    rounded_rectangle(draw, [20, y, 355, y + 56], 16, COLORS['surface'])

    rounded_rectangle(draw, [36, y + 8, 72, y + 48], 12, bg_color)
    try:
        emoji_font = ImageFont.truetype("C:\\Windows\\Fonts\\seguiemj.ttf", 24)
    except:
        emoji_font = ImageFont.load_default()
    draw_text_centered(draw, icon, 54, y + 18, emoji_font, (0, 0, 0))

    draw.text([84, y + 14], title, font=item_font, fill=COLORS['text_primary'])
    draw.text([84, y + 36], value, font=value_font, fill=COLORS['text_secondary'])
    draw.text([335, y + 24], "›", font=item_font, fill=COLORS['text_secondary'])

draw_bottom_nav(draw, active=2)
img.save(os.path.join(output_dir, "03_settings.png"))
print("[OK] Settings screen saved")

# 创建报告页
print("Creating report screen...")
img = Image.new('RGB', (WIDTH, HEIGHT), COLORS['background'])
draw = ImageDraw.Draw(img)

draw_header(draw, "本周报告")

# 积分卡片
for y in range(120, 220):
    ratio = (y - 120) / 100
    r = int(COLORS['points_start'][0] * (1 - ratio) + COLORS['points_end'][0] * ratio)
    g = int(COLORS['points_start'][1] * (1 - ratio) + COLORS['points_end'][1] * ratio)
    b = int(COLORS['points_start'][2] * (1 - ratio) + COLORS['points_end'][2] * ratio)
    draw.rectangle([20, y, 355, y + 1], fill=(r, g, b))

try:
    points_font = ImageFont.truetype("C:\\Windows\\Fonts\\arialbd.ttf", 64)
    label_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 14)
    title_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 16)
    bar_label_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 11)
    stat_font = ImageFont.truetype("C:\\Windows\\Fonts\\arialbd.ttf", 32)
    stat_label_font = ImageFont.truetype("C:\\Windows\\Fonts\\msyh.ttc", 12)
except:
    points_font = ImageFont.load_default()
    label_font = ImageFont.load_default()
    title_font = ImageFont.load_default()
    bar_label_font = ImageFont.load_default()
    stat_font = ImageFont.load_default()
    stat_label_font = ImageFont.load_default()

draw_text_centered(draw, "186", 187, 150, points_font, (255, 255, 255))
draw_text_centered(draw, "阳光积分", 187, 218, label_font, (255, 255, 255))

# 每日使用图表
rounded_rectangle(draw, [20, 240, 355, 410], 24, COLORS['surface'])
draw.text([44, 268], "每日使用", font=title_font, fill=COLORS['text_primary'])

bar_heights = [80, 60, 100, 45, 70, 90, 55]
bar_colors = [
    (236, 139, 159),
    (240, 197, 208),
    (245, 217, 226),
    (232, 184, 202),
    (216, 154, 170),
    (201, 122, 144),
    (216, 154, 170),
]
days = ["一", "二", "三", "四", "五", "六", "日"]

for i, (h, color, day) in enumerate(zip(bar_heights, bar_colors, days)):
    x = 44 + i * 45
    y_bar = 370 - h
    rounded_rectangle(draw, [x, y_bar, x + 32, 368], 10, color)
    draw_text_centered(draw, day, x + 16, 380, bar_label_font, COLORS['text_secondary'])

# 统计网格
stats = [
    ("7.2", "本周平均(小时)"),
    ("5", "达标天数"),
    ("⭐", "表现优秀"),
    ("🎮", "最爱: 我的世界"),
]

for i, (value, label) in enumerate(stats):
    row = i // 2
    col = i % 2
    x = 20 + col * 167
    y = 430 + row * 100

    rounded_rectangle(draw, [x, y, x + 168, y + 88], 20, COLORS['surface'])
    draw_text_centered(draw, value, x + 84, y + 28, stat_font, COLORS['primary'])
    draw_text_centered(draw, label, x + 84, y + 62, stat_label_font, COLORS['text_secondary'])

draw_bottom_nav(draw, active=2)
img.save(os.path.join(output_dir, "04_report.png"))
print("[OK] Report screen saved")

print(f"\n[OK] All screenshots saved to: {output_dir}")
