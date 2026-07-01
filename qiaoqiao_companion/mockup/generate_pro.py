# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
import os

WIDTH, HEIGHT = 375, 812
os.makedirs('screens_pro', exist_ok=True)

def get_font(size, bold=False):
    fonts = [
        "C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/simhei.ttf",
        "arial.ttf"
    ]
    for f in fonts:
        try:
            return ImageFont.truetype(f, size)
        except:
            continue
    return ImageFont.load_default()

def draw_rounded_rect(draw, box, radius, fill, outline=None, width=1):
    x1, y1, x2, y2 = box
    if x1 > x2: x1, x2 = x2, x1
    if y1 > y2: y1, y2 = y2, y1
    draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=fill, outline=outline, width=width)

# ============ V1: 柔和樱花风 ============
def draw_v1():
    img = Image.new('RGB', (WIDTH, HEIGHT), '#FFF5F7')
    draw = ImageDraw.Draw(img)

    # Header
    draw.text((20, 60), "纹纹小伙伴", font=get_font(26, True), fill='#D46A8A')

    # Avatar card with shadow
    y = 110
    # Shadow
    draw_rounded_rect(draw, [24, y+4, WIDTH-16, y+124], 28, '#F0D0D8')
    draw_rounded_rect(draw, [20, y, WIDTH-20, y+120], 28, '#FFFFFF')

    # Avatar
    draw.rounded_rectangle([40, y+15, 90, y+65], radius=20, fill='#FFB6C1')
    draw.text((65, y+40), "Q", font=get_font(32), fill='#FFFFFF', anchor='mm')

    # Name
    draw.text((105, y+25), "巧巧", font=get_font(22, True), fill='#4A4A4A')
    draw.text((105, y+55), "今天也是元气满满的一天~", font=get_font(13), fill='#999999')

    # Time card
    y = 260
    draw_rounded_rect(draw, [24, y+4, WIDTH-16, y+164], 32, '#F0D0D8')
    draw_rounded_rect(draw, [20, y, WIDTH-20, y+160], 32, '#FFFFFF')

    # Circle progress background
    cx, cy = WIDTH//2, y+80
    draw.ellipse([cx-70, cy-70, cx+70, cy+70], fill='#F8F8F8', outline='#FFE4E9', width=8)

    # Progress arc (70% filled)
    for angle in range(0, 252):
        import math
        rad = math.radians(angle - 90)
        x1 = cx + 66 * math.cos(rad)
        y1 = cy + 66 * math.sin(rad)
        x2 = cx + 62 * math.cos(rad)
        y2 = cy + 62 * math.sin(rad)
        draw.line([x1, y1, x2, y2], fill='#FFB6C1', width=8)

    # Time text
    draw.text((cx, cy-10), "2h30m", font=get_font(36, True), fill='#D46A8A', anchor='mm')
    draw.text((cx, cy+20), "今日使用时长", font=get_font(13), fill='#999999', anchor='mm')

    # Apps section
    y = 460
    draw.text((20, y), "常用应用", font=get_font(18, True), fill='#4A4A4A')

    apps = [
        ("微信", "#07C160", "45分钟", "💬"),
        ("抖音", "#FF6B6B", "32分钟", "🎵"),
        ("B站", "#FB7299", "28分钟", "📺"),
    ]

    for i, (name, color, time, emoji) in enumerate(apps):
        ay = y + 35 + i * 75
        draw_rounded_rect(draw, [22, ay+2, WIDTH-18, ay+72], 20, '#F0D0D8')
        draw_rounded_rect(draw, [20, ay, WIDTH-20, ay+70], 20, '#FFFFFF')

        # Icon
        draw.rounded_rectangle([30, ay+10, 75, ay+60], radius=16, fill=color+'20')
        draw.rounded_rectangle([32, ay+12, 73, ay+58], radius=14, fill=color)
        draw.text((52, ay+35), emoji, font=get_font(24), anchor='mm')

        draw.text(85, ay+18], name, font=get_font(16, True), fill='#4A4A4A')
        draw.text(85, ay+42], time, font=get_font(14), fill='#D46A8A')

    img.save('screens_pro/v1_sakura.png')
    print('Generated v1_sakura.png')

# ============ V2: 清新薄荷风 ============
def draw_v2():
    img = Image.new('RGB', (WIDTH, HEIGHT), '#F8FBF9')
    draw = ImageDraw.Draw(img)

    # Header with white card
    draw.rounded_rectangle([0, 0, WIDTH, 130], radius=[0,0,30,30], fill='#FFFFFF')

    draw.text(20, 60], "纹纹小伙伴", font=get_font(26, True), fill='#1A1A1A')
    draw.text(20, 92], "Manage your time wisely", font=get_font(12), fill='#999999')

    # Stats cards
    y = 150
    draw_rounded_rect(draw, [20, y, 175, y+100], 20, '#FFFFFF')
    draw_rounded_rect(draw, [200, y, 355, y+100], 20, '#FFFFFF')

    draw.text(97, y+30], "2.5h", font=get_font(32, True), fill='#2E8B7A', anchor='mm')
    draw.text(97, y+60], "今日使用", font=get_font(12), fill='#999999', anchor='mm')

    draw.text(277, y+30], "82%", font=get_font(32, True), fill='#2E8B7A', anchor='mm')
    draw.text(277, y+60], "达成率", font=get_font(12), fill='#999999', anchor='mm')

    # Progress card
    y = 270
    draw_rounded_rect(draw, [20, y, WIDTH-20, y+180], 24, '#FFFFFF')

    draw.text(40, y+25], "今日限额", font=get_font(16, True), fill='#1A1A1A'])
    draw.text(WIDTH-40, y+25], "62%", font=get_font(32, True), fill='#2E8B7A', anchor='mm')

    # Progress bar background
    draw_rounded_rect(draw, [40, y+60, WIDTH-40, y+80], 10, '#F0F0F0')
    # Progress bar fill
    draw_rounded_rect(draw, [40, y+60, 40+(WIDTH-80)*0.62, y+80], 10, '#2E8B7A')

    draw.text(40, y+100], "已用 2h30m", font=get_font(12), fill='#999999'])
    draw.text(WIDTH-40, y+100], "限额 4h", font=get_font(12), fill='#999999', anchor='mm')

    # Apps list
    y = 480
    draw.text(20, y], "应用使用排行", font=get_font(16, True), fill='#1A1A1A'])

    apps = [
        ("微信", "#07C160", "45分", "💬"),
        ("抖音", "#000000", "32分", "🎵"),
        ("B站", "#FB7299", "28分", "📺"),
        ("王者", "#FF9800", "25分", "🎮"),
    ]

    for i, (name, color, time, emoji) in enumerate(apps):
        ay = y + 30 + i * 62
        draw_rounded_rect(draw, [20, ay, WIDTH-20, ay+56], 16, '#FFFFFF')

        draw.rounded_rectangle([28, ay+8, 68, ay+48], radius=12, fill=color+'30')
        draw.rounded_rectangle([30, ay+10, 66, ay+46], radius=10, fill=color)
        draw.text(48, ay+28], emoji, font=get_font(20), anchor='mm')

        draw.text(78, ay+18], name, font=get_font(15, True), fill='#1A1A1A'])
        draw.text(WIDTH-35, ay+18], time, font=get_font(14, True), fill='#2E8B7A', anchor='mm')

    img.save('screens_pro/v2_mint.png')
    print('Generated v2_mint.png')

# ============ V3: 活力糖果风 ============
def draw_v3():
    img = Image.new('RGB', (WIDTH, HEIGHT), '#FFF9E6')
    draw = ImageDraw.Draw(img)

    # Header
    draw.text(20, 60], "纹纹小伙伴", font=get_font(28, True), fill='#FF6B6B')
    draw.text(20, 95], "让时间管理变得有趣！", font=get_font(14), fill='#FFA06B')

    # Avatar card with decorations
    y = 130
    # Decorative dots
    for i in range(8):
        draw.ellipse([30+i*42, y-5, 36+i*42, y+1], fill='#FFB6C1')

    draw_rounded_rect(draw, [20, y, WIDTH-20, y+150], 30, '#FFE4E8')
    draw_rounded_rect(draw, [20, y, WIDTH-20, y+150], 30, '#FFFFFF', outline='#FFB6C1', width=3)

    # Avatar
    draw.ellipse([45, y+20, 105, y+80], fill='#FFE066')
    draw.ellipse([50, y+25, 100, y+75], fill='#FFD866')
    draw.text(75, y+50], "😊", font=get_font(32), anchor='mm')

    draw.text(120, y+35], "巧巧", font=get_font(24, True), fill='#333333'])
    draw.text(120, y+65], "今天要控制玩手机的时间哦~", font=get_font(12), fill='#999999'])

    # Badges
    badge_y = y+105
    draw.rounded_rectangle([35, badge_y, 115, badge_y+30], radius=15, fill='#FF9A9E')
    draw.text(75, badge_y+15], "🏆 小达人", font=get_font(12), fill='#FFFFFF', anchor='mm')

    draw.rounded_rectangle([125, badge_y, 195, badge_y+30], radius=15, fill='#FFD93D')
    draw.text(160, badge_y+15], "⭐ 三星", font=get_font(12), fill='#FFFFFF', anchor='mm')

    # Time card
    y = 320
    draw_rounded_rect(draw, [20, y, WIDTH-20, y+130], 28, '#FFFFFF')

    draw.text(WIDTH//2, y+35], "2h30m", font=get_font(48, True), fill='#FF6B6B', anchor='mm')
    draw.text(WIDTH//2, y+75], "今日已使用时间", font=get_font(14), fill='#FFA06B', anchor='mm')

    # Color circles
    circles_y = y+95
    colors = ['#FF9A9E', '#FFA06B', '#FFE066', '#4ECDC4']
    labels = ['微信', '抖音', 'B站', '游戏']
    for i, (color, label) in enumerate(zip(colors, labels)):
        cx = 55 + i*75
        draw.ellipse([cx-22, circles_y-22, cx+22, circles_y+22], fill=color)
        draw.text(cx, circles_y+1], label[:2], font=get_font(10), fill='#FFFFFF', anchor='mm')

    # Apps with stars
    y = 490
    draw.text(20, y], "我的应用使用", font=get_font(18, True), fill='#333333'])

    apps = [
        ("微信", "#07C160", "45分钟", "💬", 3),
        ("抖音", "#FF6B6B", "32分钟", "🎵", 2),
        ("B站", "#FB7299", "28分钟", "📺", 2),
    ]

    for i, (name, color, time, emoji, stars) in enumerate(apps):
        ay = y + 30 + i * 75
        draw_rounded_rect(draw, [20, ay, WIDTH-20, ay+68], 22, '#FFFFFF')

        draw.rounded_rectangle([30, ay+10, 75, ay+58], radius=18, fill=color+'40')
        draw.rounded_rectangle([32, ay+12, 73, ay+56], radius=16, fill=color)
        draw.text(52, ay+34], emoji, font=get_font(22), anchor='mm')

        draw.text(85, ay+20], name, font=get_font(16, True), fill='#333333'])
        draw.text(85, ay+45], time, font=get_font(13), fill='#FF6B6B'])

        # Stars
        stars_x = WIDTH-60
        for s in range(stars):
            draw.text(stars_x+s*20, ay+32], "⭐", font=get_font(14))

    img.save('screens_pro/v3_candy.png')
    print('Generated v3_candy.png')

# Generate all
draw_v1()
draw_v2()
draw_v3()

# Combine all versions
print('\nCombining all versions...')
images = [
    Image.open('screens_pro/v1_sakura.png'),
    Image.open('screens_pro/v2_mint.png'),
    Image.open('screens_pro/v3_candy.png'),
]

gap = 40
total_width = WIDTH + 200  # Add space for labels
total_height = sum(img.height for img in images) + gap * (len(images)-1)

combined = Image.new('RGB', (total_width, total_height), '#E8E8E8')

y_offset = 0
for i, img in enumerate(images):
    # Add label
    label_img = Image.new('RGB', (200, img.height), '#E8E8E8')
    label_draw = ImageDraw.Draw(label_img)

    labels = [
        ("V1 柔和樱花风", "#FFB6C1", "温柔粉系 · 圆润字体"),
        ("V2 清新薄荷风", "#2E8B7A", "苹果简洁 · 薄荷配色"),
        ("V3 活力糖果风", "#FF6B6B", "手写风格 · 趣味性强"),
    ]

    title, color, desc = labels[i]
    label_draw.text((100, img.height//2-30), title, font=get_font(20, True), fill=color, anchor='mm')
    label_draw.text((100, img.height//2+10), desc, font=get_font(12), fill='#666666', anchor='mm')

    combined.paste(label_img, (0, y_offset))
    combined.paste(img, (200, y_offset))
    y_offset += img.height + gap

combined.save('screens_pro/ui_versions_pro.png')
print(f'\nGenerated: screens_pro/ui_versions_pro.png ({total_width}x{total_height})')
