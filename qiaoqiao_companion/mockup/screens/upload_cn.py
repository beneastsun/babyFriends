# -*- coding: utf-8 -*-
import requests

image_path = "ui_design_small.jpg"

# Try multiple image hosts
hosts = [
    ("https://www.ftpkp.com/upload", None, "ftpkp"),
    ("https://img.1zone.site/api/v1/upload", None, "1zone"),
    ("https://imgapi.photo/acgbox", None, "photo"),
]

for url, headers, name in hosts:
    try:
        print(f"Trying {name}...")
        with open(image_path, 'rb') as f:
            files = {'file': f}
            resp = requests.post(url, files=files, data={}, timeout=30)
            print(f"  Status: {resp.status_code}")
            print(f"  Response: {resp.text[:500]}")
            if resp.status_code == 200:
                print(f"  SUCCESS with {name}!")
                break
    except Exception as e:
        print(f"  Error: {e}")
    print()
