# -*- coding: utf-8 -*-
from PIL import Image
import os

# Open 4 images
names = ['01_home.png', '02_rules.png', '03_settings.png', '04_report.png']
images = []

for name in names:
    img = Image.open(name)
    # Convert to RGB
    if img.mode != 'RGB':
        img = img.convert('RGB')
    images.append(img)

# Save as PDF with PNG format (no JPEG needed)
pdf_path = 'ui_design.pdf'
images[0].save(pdf_path, save_all=True, append_images=images[1:],
               format='PDF', resolution=100.0)

print(f'Generated: {pdf_path}')
print(f'Pages: {len(images)}')
