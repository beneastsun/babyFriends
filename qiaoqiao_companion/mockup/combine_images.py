# -*- coding: utf-8 -*-
from PIL import Image
import os

# 打开4张图片
screens_dir = 'screens'
images = []
for f in sorted(os.listdir(screens_dir)):
    if f.endswith('.png'):
        img = Image.open(os.path.join(screens_dir, f))
        images.append(img)

# 计算总尺寸
img_width = images[0].width
img_height = images[0].height
gap = 40  # 图片之间的间距

total_width = img_width
total_height = img_height * len(images) + gap * (len(images) - 1)

# 创建空白长图
combined = Image.new('RGB', (total_width, total_height), '#FAF9F8')

# 拼接图片
y_offset = 0
for img in images:
    combined.paste(img, (0, y_offset))
    y_offset += img_height + gap

# 保存
output_path = 'screens/ui_design_combined.png'
combined.save(output_path, 'PNG', optimize=True)
print(f'Generated: {output_path}')
print(f'Size: {total_width} x {total_height}px')
