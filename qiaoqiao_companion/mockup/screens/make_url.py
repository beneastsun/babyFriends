# -*- coding: utf-8 -*-
import base64
import urllib.parse

# Read image
with open('ui_design_small.jpg', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()

# Create HTML - use double quotes to avoid Python f-string confusion
html = """<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>UI Design</title>
<style>body{margin:0;background:#f5f5f5;padding:10px;display:flex;justify-content:center}
img{max-width:100%;border-radius:12px;box-shadow:0 4px 20px rgba(0,0,0,0.1)}</style>
</head><body>
<img src="data:image/jpeg;base64,""" + b64 + """\" alt="UI">
</body></html>"""

# Save HTML
with open('view_design.html', 'w', encoding='utf-8') as f:
    f.write(html)

print(f'HTML file: view_design.html')
print(f'File size: {len(html)} bytes')
print(f'Image base64 length: {len(b64)}')
