# -*- coding: utf-8 -*-
import requests
import os

# Read image
with open('ui_design_combined.png', 'rb') as f:
    files = {'file': ('ui_design.png', f, 'image/png')}

    # Try different hosts
    hosts = [
        ('https://0x0.st', None),
        ('https://x0.at', None),
    ]

    for host, headers in hosts:
        try:
            print(f'Trying {host}...')
            resp = requests.post(host, files=files, timeout=30)
            if resp.status_code == 200 and resp.text.strip():
                print(f'Success! URL: {resp.text.strip()}')
                break
        except Exception as e:
            print(f'Failed: {e}')
