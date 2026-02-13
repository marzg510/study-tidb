#!/bin/bash
# TiDB Chaos Experiment Runner
# 障害を注入して監視を自動実行

set -e

NAMESPACE="sample"

echo "========================================"
echo "  TiDB Chaos Experiment Runner"
echo "========================================"
echo ""

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 実験タイプの選択
echo "Select chaos experiment type:"
echo "1) Short IOChaos (30s, 50% error rate)"
echo "2) Long IOChaos (5m, 50% error rate)"
echo "3) High severity IOChaos (2m, 100% error rate)"
echo "4) I/O Latency (2m, 100ms delay)"
echo "5) Pod Chaos - Pod Failure (1m)"
echo "6) Pod Chaos - Pod Kill"
echo "7) Network Chaos - 200ms delay"
echo "8) Stress Test - CPU stress"
read -p "Enter choice [1-8]: " CHOICE

# 既存のChaosリソースを削除
echo ""
echo "${YELLOW}Cleaning up existing chaos experiments...${NC}"
kubectl delete iochaos -n $NAMESPACE --all 2>/dev/null || true
kubectl delete podchaos -n $NAMESPACE --all 2>/dev/null || true
kubectl delete networkchaos -n $NAMESPACE --all 2>/dev/null || true
kubectl delete stresschaos -n $NAMESPACE --all 2>/dev/null || true
sleep 2

# 実験YAMLを生成
case $CHOICE in
    1)
        echo "${BLUE}Preparing: Short IOChaos (30s, 50% error)${NC}"
        DURATION="30s"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-chaos-experiment
  namespace: sample
spec:
  action: fault
  mode: one
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
  volumePath: /var/lib/tikv
  path: /var/lib/tikv/db/*.sst
  errno: 5
  percent: 50
  duration: "30s"
EOF
        ;;
    2)
        echo "${BLUE}Preparing: Long IOChaos (5m, 50% error)${NC}"
        DURATION="5m"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-chaos-experiment
  namespace: sample
spec:
  action: fault
  mode: one
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
  volumePath: /var/lib/tikv
  path: /var/lib/tikv/db/*.sst
  errno: 5
  percent: 50
  duration: "5m"
EOF
        ;;
    3)
        echo "${BLUE}Preparing: High Severity IOChaos (2m, 100% error)${NC}"
        DURATION="2m"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-chaos-experiment
  namespace: sample
spec:
  action: fault
  mode: one
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
  volumePath: /var/lib/tikv
  path: /var/lib/tikv/db/*.sst
  errno: 5
  percent: 100
  duration: "2m"
EOF
        ;;
    4)
        echo "${BLUE}Preparing: I/O Latency (2m, 100ms delay)${NC}"
        DURATION="2m"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-chaos-experiment
  namespace: sample
spec:
  action: latency
  mode: one
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
  volumePath: /var/lib/tikv
  path: /var/lib/tikv/**/*
  delay: "100ms"
  duration: "2m"
EOF
        ;;
    5)
        echo "${BLUE}Preparing: Pod Failure (1m)${NC}"
        DURATION="1m"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-chaos-experiment
  namespace: sample
spec:
  action: pod-failure
  mode: one
  duration: "1m"
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
EOF
        ;;
    6)
        echo "${BLUE}Preparing: Pod Kill (instant)${NC}"
        DURATION="10s"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-chaos-experiment
  namespace: sample
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
EOF
        ;;
    7)
        echo "${BLUE}Preparing: Network Delay (200ms, 2m)${NC}"
        DURATION="2m"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-chaos-experiment
  namespace: sample
spec:
  action: delay
  mode: one
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
  delay:
    latency: "200ms"
    correlation: "50"
    jitter: "50ms"
  duration: "2m"
EOF
        ;;
    8)
        echo "${BLUE}Preparing: CPU Stress (2m)${NC}"
        DURATION="2m"
        cat > /tmp/chaos-experiment.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: stress-chaos-experiment
  namespace: sample
spec:
  mode: one
  selector:
    namespaces:
      - sample
    labelSelectors:
      app.kubernetes.io/component: tikv
  stressors:
    cpu:
      workers: 2
      load: 80
  duration: "2m"
EOF
        ;;
    *)
        echo "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "${GREEN}Starting baseline monitoring (10 seconds)...${NC}"
echo "Verifying cluster is healthy before chaos injection..."
echo ""

# ベースライン監視（10秒）
for i in {1..5}; do
    RESULT=$(kubectl exec -n $NAMESPACE mysql-client -- \
        mysql -h sample-cluster-tidb -P 4000 -u root \
        -e "SELECT NOW(), COUNT(*) FROM information_schema.tables;" 2>&1 | tail -1)
    echo "[$i/5] $RESULT"
    sleep 2
done

echo ""
echo "${YELLOW}===== INJECTING CHAOS =====${NC}"
kubectl apply -f /tmp/chaos-experiment.yaml

echo ""
echo "${RED}Chaos experiment started!${NC}"
echo "Expected duration: $DURATION"
echo ""
echo "Starting continuous monitoring..."
echo "Press Ctrl+C to stop monitoring"
echo ""

sleep 3

# モニタリングスクリプトを実行
bash monitor-chaos.sh
