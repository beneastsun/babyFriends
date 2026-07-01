# -*- coding: utf-8 -*-
import requests

# Try ImgBB API
api_key = "c40d50294550d75"
image_path = "ui_design_combined.png"

try:
    with open(image_path, 'rb') as f:
        response = requests.post(
            'https://api.imgbb.com/1/upload',
            params={'key': api_key},
            files={'image': f},
            timeout=60
        )
        print(f'Status: {response.status_code}')
        if response.status_code == 200:
            data = response.json()
            url = data['data']['url']
            print(f'Direct URL: {url}')
            print(f'Delete URL: {data["data"].get("delete_url", "N/A")}')
        else:
            print(f'Response: {response.text[:500]}')
except Exception as e:
    print(f'Error: {e}')
