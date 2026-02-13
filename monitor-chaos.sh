#!/bin/bash
# TiDB Chaos Monitoring Script
# 障害注入の効果をリアルタイムで監視

NAMESPACE="sample"
INTERVAL=2  # 監視間隔（秒）

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "  TiDB Chaos Experiment Monitor"
echo "========================================"
echo ""

# ログファイル作成
LOGFILE="chaos-monitor-$(date +%Y%m%d-%H%M%S).log"
echo "ログファイル: $LOGFILE"
echo ""

# ヘッダー
printf "%-19s | %-6s | %-30s | %-10s\n" "Time" "Status" "Response" "Pod Status"
printf "%s\n" "---------------------------------------------------------------------------------------------------"

# ログファイルにもヘッダー書き込み
printf "%-19s | %-6s | %-30s | %-10s\n" "Time" "Status" "Response" "Pod Status" >> "$LOGFILE"
printf "%s\n" "---------------------------------------------------------------------------------------------------" >> "$LOGFILE"

# 前回のPod状態を記録
PREV_POD_STATUS=""

# カウンター
SUCCESS_COUNT=0
ERROR_COUNT=0
ITERATION=0

while true; do
    ITERATION=$((ITERATION + 1))
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # SQLクエリを実行
    QUERY_RESULT=$(kubectl exec -n $NAMESPACE mysql-client -- \
        mysql -h sample-cluster-tidb -P 4000 -u root \
        -e "SELECT NOW(), COUNT(*) FROM information_schema.tables;" 2>&1)

    # 実行結果を判定
    if echo "$QUERY_RESULT" | grep -q "ERROR\|Lost connection\|Can't connect"; then
        STATUS="${RED}ERROR${NC}"
        STATUS_LOG="ERROR"
        RESPONSE=$(echo "$QUERY_RESULT" | grep -oP "(ERROR|Lost connection|Can't connect).*" | head -1 | cut -c1-30)
        ERROR_COUNT=$((ERROR_COUNT + 1))
    elif echo "$QUERY_RESULT" | grep -q "NOW()"; then
        STATUS="${GREEN}OK${NC}"
        STATUS_LOG="OK"
        # テーブル数を抽出
        TABLE_COUNT=$(echo "$QUERY_RESULT" | tail -1 | awk '{print $NF}')
        RESPONSE="Tables: $TABLE_COUNT"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        STATUS="${YELLOW}UNKNOWN${NC}"
        STATUS_LOG="UNKNOWN"
        RESPONSE="Unexpected response"
    fi

    # Pod状態を取得
    POD_STATUS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=tikv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount --no-headers 2>&1)

    # Pod状態の変化を検出
    if [ "$POD_STATUS" != "$PREV_POD_STATUS" ]; then
        POD_CHANGE="${YELLOW}CHANGED${NC}"
        POD_CHANGE_LOG="CHANGED"
    else
        POD_CHANGE="       "
        POD_CHANGE_LOG="       "
    fi
    PREV_POD_STATUS="$POD_STATUS"

    # 簡潔なPod状態（Running以外を強調）
    POD_SUMMARY=$(echo "$POD_STATUS" | awk '{
        if ($2 != "Running") printf "[%s:%s:%s] ", $1, $2, $3
        else if ($3 > 0) printf "[%s:R:%s] ", $1, $3
    }')
    if [ -z "$POD_SUMMARY" ]; then
        POD_SUMMARY="All Running (0 restarts)"
    fi

    # コンソール出力（色付き）
    printf "%-19s | ${STATUS} | %-30s | %s %s\n" \
        "$TIMESTAMP" "$RESPONSE" "$POD_CHANGE" "$POD_SUMMARY"

    # ログファイル出力（色なし）
    printf "%-19s | %-6s | %-30s | %s %s\n" \
        "$TIMESTAMP" "$STATUS_LOG" "$RESPONSE" "$POD_CHANGE_LOG" "$POD_SUMMARY" >> "$LOGFILE"

    # 10回ごとに統計を表示
    if [ $((ITERATION % 10)) -eq 0 ]; then
        echo ""
        echo "${BLUE}--- Statistics (${ITERATION} iterations) ---${NC}"
        echo "Success: $SUCCESS_COUNT, Errors: $ERROR_COUNT"
        AVAILABILITY=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS_COUNT / $ITERATION) * 100}")
        echo "Availability: ${AVAILABILITY}%"
        echo ""

        # IOChaosの状態も確認
        IOCHAOS_STATUS=$(kubectl get iochaos -n $NAMESPACE io-delay-tikv -o jsonpath='{.status.conditions[?(@.type=="AllInjected")].status}' 2>/dev/null)
        if [ "$IOCHAOS_STATUS" = "True" ]; then
            echo "${RED}IOChaos: ACTIVE (障害注入中)${NC}"
        else
            echo "${GREEN}IOChaos: INACTIVE (正常状態)${NC}"
        fi
        echo ""

        # ヘッダー再表示
        printf "%-19s | %-6s | %-30s | %-10s\n" "Time" "Status" "Response" "Pod Status"
        printf "%s\n" "---------------------------------------------------------------------------------------------------"
    fi

    sleep $INTERVAL
done
