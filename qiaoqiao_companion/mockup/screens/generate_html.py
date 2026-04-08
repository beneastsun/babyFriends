# -*- coding: utf-8 -*-
import base64

# Read compressed image
with open('ui_design_small.jpg', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()

# Generate HTML
html = f'''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>纹纹小伙伴 UI设计</title>
<style>
body{{margin:0;background:#f5f5f5;padding:10px;display:flex;justify-content:center}}
img{{max-width:100%;border-radius:12px;box-shadow:0 4px 20px rgba(0,0,0,0.1)}}
</style>
</head>
<body>
<img src="data:image/jpeg;base64,{b64}" alt="UI设计效果图">
</body>
</html>'''

with open('ui_design_view.html', 'w', encoding='utf-8') as f:
    f.write(html)

print('Generated: ui_design_view.html')
print(f'HTML size: {len(html)} chars')
