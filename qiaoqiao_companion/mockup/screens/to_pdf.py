# -*- coding: utf-8 -*-
from PIL import Image
import os

# Open 4 images
screens_dir = '.'
images = []
names = ['01_home.png', '02_rules.png', '03_settings.png', '04_report.png']
titles = ['1. 首页 - 巧巧卡片 + 使用时间圆环 + 应用排行',
          '2. 规则页 - 时间规则卡片 + 应用分类开关',
          '3. 设置页 - 简洁列表风格',
          '4. 报告页 - 积分卡片 + 周统计柱状图']

for name in names:
    img = Image.open(os.path.join(screens_dir, name))
    images.append(img)

# Create PDF
pdf_path = 'ui_design.pdf'
# Convert to RGB mode first
rgb_images = [img.convert('RGB') for img in images]
rgb_images[0].save(pdf_path, save_all=True, append_images=rgb_images[1:],
                   resolution=150.0, quality=95)

print(f'Generated: {pdf_path}')
print(f'Pages: {len(images)}')
