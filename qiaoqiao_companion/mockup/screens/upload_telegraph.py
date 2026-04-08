# -*- coding: utf-8 -*-
import requests
import json

# Create Telegraph page
telegraph_token = "d3b8585242a38e4ad92588685f2b455025324353524152345234525052435"

# Get page path from image - we'll create a simple page
content = '''
<p>纹纹小伙伴 UI设计效果图</p>
<img src="https://i.328888.xyz/2023/04/07/v9L4g.png" />
<p>1. 首页 - 巧巧卡片 + 使用时间圆环 + 应用排行</p>
<img src="https://i.328888.xyz/2023/04/07/v9WpS.png" />
<p>2. 规则页 - 时间规则卡片 + 应用分类开关</p>
<img src="https://i.328888.xyz/2023/04/07/v9OZ0.png" />
<p>3. 设置页 - 简洁列表风格</p>
<img src="https://i.328888.xyz/2023/04/07/v9NlG.png" />
<p>4. 报告页 - 积分卡片 + 周统计柱状图</p>
'''

try:
    resp = requests.post('https://api.telegra.ph/createPage',
        data={
            'access_token': telegraph_token,
            'title': '纹纹小伙伴 UI设计',
            'author_name': '纹纹小伙伴',
            'content': json.dumps([{'tag': 'p', 'children': content}]),
            'return_content': True
        }, timeout=30)
    print(f'Status: {resp.status_code}')
    result = resp.json()
    print(json.dumps(result, indent=2, ensure_ascii=False))
except Exception as e:
    print(f'Error: {e}')
