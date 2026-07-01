# -*- coding: utf-8 -*-
import requests
import base64

# Read and encode image
with open('ui_design_combined.png', 'rb') as f:
    image_data = f.read()
    b64_data = base64.b64encode(image_data).decode()

# Try gyazo (simple upload)
url = "https://upload.gyazo.com/api/upload"
try:
    resp = requests.post(url, data={'imagedata': b64_data}, timeout=30)
    print(f'Status: {resp.status_code}')
    print(resp.text)
except Exception as e:
    print(f'Error: {e}')
