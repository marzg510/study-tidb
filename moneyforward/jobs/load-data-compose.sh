#!/bin/bash
set -e

CSV_DIR="/mnt/g/マイドライブ/life/家計/マネーフォワード/"

# export IN_PATH=${CSV_DIR}/2025/収入・支出詳細_2025-01-01_2025-01-31.csv
export IN_PATH=$1
# export TARGET_YM=2025-01
export TARGET_YM=$2
export IN_DIR=`dirname $IN_PATH`
export IN_FILE=`basename $IN_PATH`
docker compose -f load-data-compose.yaml down --volumes
docker compose -f load-data-compose.yaml up
