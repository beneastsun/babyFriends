# -*- coding: utf-8 -*-
from PIL import Image
import base64

# Open and resize image
img = Image.open('ui_design_combined.png')

# Get current size
print(f'Original size: {img.size}')

# Resize to 50% for smaller file
new_size = (img.size[0] // 2, img.size[1] // 2)
img_small = img.resize(new_size, Image.Resampling.LANCZOS)

# Save with compression
img_small.save('ui_design_small.jpg', 'JPEG', quality=70, optimize=True)

# Get file size
import os
size = os.path.getsize('ui_design_small.jpg')
print(f'Compressed size: {size} bytes = {size/1024:.1f} KB')

# Generate base64
with open('ui_design_small.jpg', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()
    print(f'Base64 length: {len(b64)}')
    print(f'First 100 chars: {b64[:100]}')
