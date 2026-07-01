# -*- coding: utf-8 -*-
import base64

# Read combined image
with open('ui_design_combined.png', 'rb') as f:
    data = f.read()
    b64 = base64.b64encode(data).decode()

# Generate HTML with embedded image
html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>纹纹小伙伴 - UI设计效果图</title>
    <style>
        body {{
            margin: 0;
            background: #f5f5f5;
            display: flex;
            justify-content: center;
            padding: 20px;
            min-height: 100vh;
        }}
        img {{
            max-width: 100%;
            border-radius: 16px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
        }}
    </style>
</head>
<body>
    <img src="data:image/png;base64,{b64}" alt="UI设计效果图">
</body>
</html>'''

with open('ui_design_embedded.html', 'w', encoding='utf-8') as f:
    f.write(html)

print(f'Generated: ui_design_embedded.html')
print(f'Image size: {len(data)} bytes = {len(data)/1024:.1f} KB')
print(f'HTML size: {len(html)} bytes = {len(html)/1024:.1f} KB')
