# -*- coding: utf-8 -*-
import requests

# Read HTML content
with open('ui_design_view.html', 'r', encoding='utf-8') as f:
    html_content = f.read()

# Try hastebin
try:
    resp = requests.post('https://hastebin.com/documents', data=html_content, timeout=30)
    print(f'Hastebin status: {resp.status_code}')
    if resp.status_code == 200:
        key = resp.json()['key']
        print(f'URL: https://hastebin.com/{key}')
except Exception as e:
    print(f'Hastebin error: {e}')

# Try另一些选项
try:
    resp = requests.post('https://pastebin.com/api/api_post.php',
        data={
            'api_dev_key': '',
            'api_option': 'paste',
            'api_paste_code': html_content[:5000],  # Free limit
        }, timeout=30)
    print(f'Pastebin: {resp.text[:200]}')
except Exception as e:
    print(f'Pastebin error: {e}')

# Try dpaste.com
try:
    resp = requests.post('https://dpaste.com/api/v2/',
        data={'content': html_content}, timeout=30)
    print(f'DPaste URL: {resp.text.strip()}')
except Exception as e:
    print(f'DPaste error: {e}')
