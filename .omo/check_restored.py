import sqlite3
conn = sqlite3.connect(r'C:\Users\chenjj\AppData\Local\Temp\qiaoqiao_db_backup\verify_restored.db')
c = conn.cursor()
print('=== Restored Settings ===')
for r in c.execute("SELECT key, value FROM app_settings WHERE key LIKE '%limit%' OR key LIKE '%rest%'"):
    print(f'  {r[0]} = {r[1]}')
conn.close()
