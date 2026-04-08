# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
import os

# Screen size
WIDTH, HEIGHT = 375, 812
screens_dir = 'screens_v2'
os.makedirs(screens_dir, exist_ok=True)

def get_font(size, bold=False):
    try:
        if bold:
            return ImageFont.truetype("arialbd.ttf", size)
        return ImageFont.truetype("arial.ttf", size)
    except:
        return ImageFont.load_default()

# ========== VERSION 1: 极简苹果风 ==========
# 更简洁，更多留白，纯白色背景，细线条
def draw_v1_minimal():
    img = Image.new('RGB', (WIDTH, HEIGHT), '#FFFFFF')
    draw = ImageDraw.Draw(img)

    # Status bar
    draw.rectangle((0, 0, WIDTH, 44), fill='#FFFFFF')

    # Header
    draw.text((20, 60), "纹纹小伙伴", font=get_font(28, True), fill='#000000')

    # Avatar card - minimal
    y = 110
    draw.rounded_rectangle([20, y, WIDTH-20, y+100], radius=20, fill='#F5F5F7')
    # Avatar circle
    draw.ellipse([40, y+15, 90, y+65], fill='#E5E5EA')
    # Name
    draw.text((105, y+25), "巧巧", font=get_font(24, True), fill='#000000')
    draw.text((105, y+55), "今天也要加油哦！", font=get_font(14), fill='#8E8E93')

    # Time circle - minimal line style
    y = 240
    draw.ellipse([WIDTH//2-70, y, WIDTH//2+70, y+140], outline='#E5E5EA', width=8)
    draw.ellipse([WIDTH//2-70, y, WIDTH//2+70, y+140], outline='#007AFF', width=8)
    # Progress - draw arc manually
    for angle in range(0, 220):
        import math
        rad = math.radians(angle - 90)
        x1 = WIDTH//2 + 66 * math.cos(rad)
        y1 = y + 70 + 66 * math.sin(rad)
        x2 = WIDTH//2 + 62 * math.cos(rad)
        y2 = y + 70 + 62 * math.sin(rad)
        draw.line([x1, y1, x2, y2], fill='#007AFF', width=8)
    draw.text((WIDTH//2, y+55), "2h30m", font=get_font(32, True), fill='#000000', anchor='mm')
    draw.text((WIDTH//2, y+85), "今日使用", font=get_font(14), fill='#8E8E93', anchor='mm')

    # Apps list - minimal
    y = 420
    draw.text((20, y), "常用应用", font=get_font(18, True), fill='#000000')
    apps = [
        ("微信", "#07C160", "45m"),
        ("抖音", "#000000", "32m"),
        ("B站", "#FB7299", "28m"),
    ]
    for i, (name, color, time) in enumerate(apps):
        ay = y + 40 + i * 70
        draw.rounded_rectangle([20, ay, WIDTH-20, ay+60], radius=12, fill='#F5F5F7')
        draw.ellipse([40, ay+12, 66, ay+38], fill=color)
        draw.text((80, ay+15), name, font=get_font(16), fill='#000000')
        draw.text((WIDTH-60, ay+20), time, font=get_font(18, True), fill='#000000', anchor='mm')

    img.save(f'{screens_dir}/v1_home.png')
    print('Generated v1_home.png')

# ========== VERSION 2: 活泼可爱风 ==========
# 圆润卡片，柔和粉色系，可爱图标
def draw_v2_cute():
    img = Image.new('RGB', (WIDTH, HEIGHT), '#FFF8F0')
    draw = ImageDraw.Draw(img)

    # Header with cute icon
    draw.text((20, 60), "纹纹小伙伴", font=get_font(28, True), fill='#FF6B8A')

    # Avatar card - cute style
    y = 110
    draw.rounded_rectangle([20, y, WIDTH-20, y+110], radius=24, fill='#FFB6C1')
    # Cute decorations
    for i in range(5):
        draw.ellipse([30+i*30, y-8, 38+i*30, y], fill='#FFD700')
    # Avatar
    draw.rounded_rectangle([40, y+15, 90, y+65], radius=20, fill='#FFFFFF')
    draw.text((65, y+40), "Q", font=get_font(28), fill='#FF6B8A', anchor='mm')
    # Name
    draw.text((105, y+25), "巧巧", font=get_font(24, True), fill='#FFFFFF')
    draw.text((105, y+55), "可爱的一天开始了~", font=get_font(13), fill='#FFFFFF')

    # Time card - cute gradient style
    y = 250
    draw.rounded_rectangle([20, y, WIDTH-20, y+150], radius=24, fill='#FFFFFF')
    # Top bar with rounded corners only at top
    draw.rectangle([20, y, WIDTH-20, y+8], fill='#FF6B8A')
    draw.ellipse([20, y, 20+16, y+16], fill='#FF6B8A')
    draw.ellipse([WIDTH-36, y, WIDTH-20, y+16], fill='#FF6B8A')

    # Draw cute progress bar
    bar_y = y + 50
    draw.rounded_rectangle([40, bar_y, WIDTH-40, bar_y+60], radius=30, fill='#FFF0F5')
    draw.rounded_rectangle([40, bar_y, 40+200, bar_y+60], radius=30, fill='#FF6B8A')
    draw.text([WIDTH//2, bar_y+30], "50%", font=get_font(24, True), fill='#FFFFFF', anchor='mm')
    draw.text([WIDTH//2, y+125], "今日已用 2h30m", font=get_font(16), fill='#FF6B8A', anchor='mm')

    # Apps - cute cards
    y = 440
    apps = [
        ("微信", "#07C160", "45分"),
        ("抖音", "#FF6B8A", "32分"),
        ("小红书", "#FF2442", "28分"),
    ]
    for i, (name, color, time) in enumerate(apps):
        ay = y + i * 85
        draw.rounded_rectangle([20, ay, WIDTH-20, ay+75], radius=20, fill='#FFFFFF')
        draw.rounded_rectangle([30, ay+10, 80, ay+65], radius=16, fill=color)
        draw.text((95, ay+20), name, font=get_font(16, True), fill='#333333')
        draw.text((95, ay+45), time, font=get_font(14), fill='#999999')
        # Star icon
        for j in range(3):
            draw.ellipse([WIDTH-50+j*12, ay+30, WIDTH-44+j*12, ay+36], fill='#FFD700')

    img.save(f'{screens_dir}/v2_home.png')
    print('Generated v2_home.png')

# ========== VERSION 3: 时尚渐变风 ==========
# 现代感，渐变色，玻璃态效果
def draw_v3_gradient():
    img = Image.new('RGB', (WIDTH, HEIGHT), '#F8F9FA')
    draw = ImageDraw.Draw(img)

    # Gradient header background
    for y in range(100):
        alpha = int(255 * (1 - y/100))
        color = f'#{255:02x}{107:02x}{138:02x}'  # #FF6B8A
        draw.rectangle([0, y, WIDTH, y+1], fill=color)

    # Header text
    draw.text((20, 55), "纹纹小伙伴", font=get_font(28, True), fill='#FFFFFF')

    # Glass morphism avatar card
    y = 130
    draw.rounded_rectangle([20, y, WIDTH-20, y+120], radius=24, fill='#FFFFFF')
    # Semi-transparent overlay
    overlay = Image.new('RGBA', (WIDTH-40, 120), (255, 255, 255, 180))
    # Draw avatar area with gradient
    draw.rounded_rectangle([40, y+20, 90, y+70], radius=16, fill='#FF6B8A')
    draw.rounded_rectangle([45, y+25, 85, y+65], radius=12, fill='#FFB6C1')
    draw.text((105, y+30), "巧巧", font=get_font(24, True), fill='#1A1A1A')
    draw.text((105, y+60), "今天是元气满满的一天！", font=get_font(13), fill='#666666')

    # Modern circular progress
    y = 280
    cx, cy = WIDTH//2, y+70
    # Background circle
    draw.ellipse([cx-80, cy-80, cx+80, cy+80], fill='#FFFFFF', outline='#E8E8E8', width=2)
    # Gradient effect arcs
    for i in range(15):
        alpha = 255 - i*15
        color = f'#FF6B8A'
        draw.arc([cx-75+i*2, cy-75+i*2, cx+75-i*2, cy+75-i*2], 0, 220, fill=color, width=3)
    draw.text((cx, cy-10), "2h30m", font=get_font(36, True), fill='#1A1A1A', anchor='mm')
    draw.text((cx, cy+25), "今日使用时长", font=get_font(14), fill='#888888', anchor='mm')

    # Modern app cards with shadow effect
    y = 460
    draw.text((20, y), "应用排行", font=get_font(18, True), fill='#1A1A1A')

    apps = [("微信", "#07C160", "45分钟"), ("抖音", "#000000", "32分钟"), ("B站", "#FB7299", "28分钟")]
    for i, (name, color, time) in enumerate(apps):
        ay = y + 40 + i * 80
        # Card with shadow
        draw.rounded_rectangle([25, ay+3, WIDTH-15, ay+73], radius=16, fill='#E8E8E8')
        draw.rounded_rectangle([20, ay, WIDTH-20, ay+70], radius=16, fill='#FFFFFF')
        # Icon
        draw.rounded_rectangle([30, ay+10, 75, ay+60], radius=14, fill=color)
        draw.text((52, ay+35), name[0], font=get_font(20), fill='#FFFFFF', anchor='mm')
        # Text
        draw.text((90, ay+20), name, font=get_font(16, True), fill='#1A1A1A')
        draw.text((90, ay+45), time, font=get_font(13), fill='#888888')
        # Progress dot
        draw.ellipse([WIDTH-50, ay+28, WIDTH-40, ay+38], fill='#FF6B8A')
        draw.ellipse([WIDTH-35, ay+28, WIDTH-25, ay+38], fill='#FFD700')
        draw.ellipse([WIDTH-20, ay+28, WIDTH-10, ay+38], fill='#E8E8E8')

    img.save(f'{screens_dir}/v3_home.png')
    print('Generated v3_home.png')

# Generate all versions
draw_v1_minimal()
draw_v2_cute()
draw_v3_gradient()

print('\nAll versions generated!')
