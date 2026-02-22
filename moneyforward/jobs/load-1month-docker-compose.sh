#!/bin/bash
set -e

export TARGET_YM=2026-01
export IN_FILE=収入・支出詳細_2026-01-01_2026-01-31.csv
docker compose -f load-1month-compose.yaml down --volumes
docker compose -f load-1month-compose.yaml up
