#!/bin/bash
set -e

echo "Database: $DB_DATABASE"
echo "Host: $DB_HOST"
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
