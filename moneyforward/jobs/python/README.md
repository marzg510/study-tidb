# TiDB Data Loader (Python版)

CSVファイルをTiDBに投入するPythonスクリプトです。

## ファイル構成

```
python/
├── Dockerfile          # Dockerイメージ定義
├── requirements.txt    # Python依存パッケージ
├── load_data.py        # データロードスクリプト
└── README.md           # このファイル
```

## 機能

1. 指定した年月のデータを削除（DELETE）
2. CSVファイルを読み込んでTiDBに投入（INSERT）
3. 投入結果の検証

## セットアップ

### 1. Dockerイメージのビルド

```bash
cd moneyforward/jobs/python
docker build -t tidb-data-loader:latest .
```

### 2. 環境変数の準備

`.env`ファイルを作成：

```bash
# TiDB接続情報
TIDB_HOST=gateway01.ap-northeast-1.prod.aws.tidbcloud.com
TIDB_PORT=4000
TIDB_USER=your_user
TIDB_PASSWORD=your_password
TIDB_DATABASE=moneyforward
TIDB_SSL_CA=/etc/tidb-ca/ca.pem
```

## 使用方法

### ローカルで実行（Pythonスクリプト直接）

```bash
# 依存パッケージインストール
pip install -r requirements.txt

# 実行
export TIDB_HOST=...
export TIDB_USER=...
export TIDB_PASSWORD=...
export TIDB_DATABASE=moneyforward

python load_data.py \
  --year-month 2026-02 \
  --input-file /path/to/transactions-utf8.csv
```

### Dockerで実行

```bash
# イメージビルド
docker build -t tidb-data-loader:latest .

# 実行
docker run --rm \
  --env-file ../../../.env \
  -v /path/to/data:/data \
  -v /path/to/isrgrootx1.pem:/etc/tidb-ca/ca.pem:ro \
  tidb-data-loader:latest \
  --year-month 2026-02 \
  --input-file /data/utf8-csv/transactions-utf8.csv
```

### 実行例（完全版）

```bash
# プロジェクトルートから実行
cd /d/gotowork/workspace/study/study-tidb

# Dockerイメージビルド
docker build -t tidb-data-loader:latest -f moneyforward/jobs/python/Dockerfile moneyforward/jobs/python/

# 実行（データディレクトリとCA証明書をマウント）
docker run --rm \
  -e TIDB_HOST=gateway01.ap-northeast-1.prod.aws.tidbcloud.com \
  -e TIDB_PORT=4000 \
  -e TIDB_USER=2JWrBN7Ky291tCf.root \
  -e TIDB_PASSWORD=Wq6InfXsCtk2TliN \
  -e TIDB_DATABASE=moneyforward \
  -v $(pwd)/data:/data:ro \
  -v $(pwd)/isrgrootx1.pem:/etc/tidb-ca/ca.pem:ro \
  tidb-data-loader:latest \
  --year-month 2026-02 \
  --input-file /data/utf8-csv/transactions-utf8.csv
```

## 出力例

```
============================================================
  TiDB Data Loader (Python)
============================================================
Year-month: 2026-02
Input file: /data/utf8-csv/transactions-utf8.csv

Connecting to TiDB...
  Host: gateway01.ap-northeast-1.prod.aws.tidbcloud.com
  Port: 4000
  Database: moneyforward
  User: 2JWrBN7Ky291tCf.root
  SSL: Enabled (CA: /etc/tidb-ca/ca.pem)
✓ Connected successfully

=== Deleting existing data for 2026-02 ===
Records to delete: 45
✓ Deleted 45 records

=== Loading CSV data ===
Input file: /data/utf8-csv/transactions-utf8.csv
File size: 15,234 bytes (14.88 KB)
Reading CSV file...
Total rows: 45
Columns: is_calculation_target, tx_date, description, amount, institution, category_major, category_minor, memo, is_transfer, id

Data preview:
   is_calculation_target     tx_date  description  amount  ...
0                      1  2026-02-01     コンビニ    -500  ...
1                      1  2026-02-03       給与  250000  ...
2                      0  2026-02-05     振替額       0  ...

Inserting data into TiDB...
  Progress: 45/45 rows inserted
✓ Inserted 45 records

=== Verifying loaded data ===
Total records in table: 1500

Data for 2026-02:
  Records: 45
  Date range: 2026-02-01 to 2026-02-28
  Total amount: 235,000

============================================================
  ✓ Data loading completed successfully!
============================================================
```

## トラブルシューティング

### SSL証明書エラー

```
Error: SSL connection failed
```

→ CA証明書のパスを確認：`-v /path/to/ca.pem:/etc/tidb-ca/ca.pem:ro`

### 環境変数エラー

```
Error: Missing required environment variables: TIDB_HOST, TIDB_USER
```

→ 環境変数を正しく設定してください

### CSVファイルが見つからない

```
Error: Input file not found: /data/utf8-csv/transactions-utf8.csv
```

→ ボリュームマウントを確認：`-v /path/to/data:/data:ro`
