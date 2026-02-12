import pandas as pd
df = pd.read_csv('収入・支出詳細_2026-02-01_2026-02-28.csv', encoding='shift_jis')
df.to_csv('transactions_utf8.csv', index=False, encoding='utf-8')
