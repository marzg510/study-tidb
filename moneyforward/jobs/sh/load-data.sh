#!/bin/bash
set -e

IN_PATH=${IN_DIR:-/data}/${IN_FILE:-transactions.csv}

echo "Database: $DB_DATABASE"
echo "Host: $DB_HOST"
echo "Input path: $IN_PATH"

echo "Target year-month: ${TARGET_YM}"

# 年月パラメータ確認
if [ -z "${TARGET_YM}" ]; then
  echo "Error: TARGET_YM environment variable is not set."
  echo "Expected format: YYYY-MM (e.g., 2024-01)"
  exit 1
fi

# 入力ファイル確認
if [ ! -f "$IN_PATH" ]; then
  echo "Error: Input file not found: $IN_PATH"
  exit 1
fi

echo "File size: $(du -h $IN_PATH | cut -f1)"
echo "Line count: $(wc -l < $IN_PATH  | tr -d ' ' ) lines"
echo "=== Starting data load process ===" 
echo ""

# データロード用SQLファイル作成
cat > /tmp/load_data.sql <<EOF
DELETE FROM mf_transactions WHERE DATE_FORMAT(tx_date, '%Y-%m') = '$TARGET_YM';
LOAD DATA LOCAL INFILE '$IN_PATH'
INTO TABLE mf_transactions
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
(is_calculation_target, tx_date, description, amount, institution, category_major, category_minor, memo, is_transfer, id)
;
EOF

echo ""
echo "=== SQL to be executed ==="
cat /tmp/load_data.sql
echo "=== End of SQL ==="
echo ""
echo "=== Connecting to DB and loading data ==="

# DBに接続してデータ投入
mysql --comments \
  -v \
  -u "$DB_USER" \
  -h "$DB_HOST" \
  -P 4000 \
  -D "$DB_DATABASE" \
  --ssl-mode=VERIFY_IDENTITY \
  --ssl-ca=/run/secrets/ca.pem \
  -p"$DB_PASSWORD" \
  --local-infile=1 \
  < /tmp/load_data.sql

# 投入結果確認
echo ""
echo "=== Verifying loaded data ==="
mysql --comments \
  -u "$DB_USER" \
  -h "$DB_HOST" \
  -P 4000 \
  -D "$DB_DATABASE" \
  --ssl-mode=VERIFY_IDENTITY \
  --ssl-ca=/run/secrets/ca.pem \
  -p"$DB_PASSWORD" \
  -e "SELECT COUNT(*) as total_rows FROM mf_transactions; SELECT COUNT(*) as loaded_rows, MIN(tx_date) as min_date, MAX(tx_date) as max_date FROM mf_transactions WHERE DATE_FORMAT(tx_date, '%Y-%m') = '${TARGET_YM}';"

echo ""
echo "=== Data loading completed successfully ==="
