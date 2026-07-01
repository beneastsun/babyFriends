# -*- coding: utf-8 -*-
import requests

# Try sm.ms
image_path = "ui_design_combined.png"

try:
    with open(image_path, 'rb') as f:
        response = requests.post(
            'https://sm.ms/api/v2/upload',
            files={'smfile': f},
            timeout=60
        )
        print(f'Status: {response.status_code}')
        print(f'Response: {response.text[:1000]}')
        if response.status_code == 200:
            data = response.json()
            if 'data' in data:
                print(f'URL: {data["data"]["url"]}')
except Exception as e:
    print(f'Error: {e}')
