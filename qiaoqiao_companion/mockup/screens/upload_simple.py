# -*- coding: utf-8 -*-
import requests
import os

image_path = "ui_design_combined.png"

# Try postimages.org (no API key needed)
url = "https://postimages.org/api/upload"

try:
    with open(image_path, 'rb') as f:
        files = {'upload': f}
        data = {
            'token': '',
            'upload_session': '',
            'numfiles': '1',
            'gallery': '',
            'option': 'thumb',  # Direct link
        }
        print("Uploading to postimages.org...")
        resp = requests.post(url, files=files, data=data, timeout=60)
        print(f"Status: {resp.status_code}")
        if resp.status_code == 200:
            print(resp.text[:1000])
except Exception as e:
    print(f"Error: {e}")

# Try pixhost
try:
    print("\nTrying pixhost...")
    with open(image_path, 'rb') as f:
        files = {'img': f}
        data = {'submit': 'upload'}
        resp = requests.post('https://pixhost.to/api/', files=files, data=data, timeout=60)
        print(f"Status: {resp.status_code}")
        print(resp.text[:500])
except Exception as e:
    print(f"Error: {e}")

# Try bayfiles
try:
    print("\nTrying bayfiles...")
    with open(image_path, 'rb') as f:
        files = {'file': f}
        resp = requests.post('https://bayfiles.com/api/upload', files=files, timeout=60)
        print(f"Status: {resp.status_code}")
        result = resp.json()
        if 'data' in result:
            print(f"Download URL: {result['data']['file']['url']['full']}")
except Exception as e:
    print(f"Error: {e}")
