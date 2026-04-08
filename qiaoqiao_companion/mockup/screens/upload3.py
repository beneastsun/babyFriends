# -*- coding: utf-8 -*-
import requests

# Try different hosts with binary data
hosts_to_try = [
    ('https://litterbox.catbox.moe/resources/internals/api.php', {'filetype': 'f', 'time': '24h'}),
    ('https://x0.at', None),
]

image_path = 'ui_design_combined.png'

for url, extra_data in hosts_to_try:
    try:
        print(f'Trying {url}...')
        with open(image_path, 'rb') as f:
            files = {'file': f}
            data = extra_data if extra_data else {}
            resp = requests.post(url, files=files, data=data, timeout=30)
            print(f'Status: {resp.status_code}')
            print(f'Response: {resp.text[:500]}')
            if resp.status_code == 200 and resp.text.strip():
                print(f'SUCCESS!')
                break
    except Exception as e:
        print(f'Failed: {e}')
    print('---')
