# study-tidb
Study TiDB

## 参考サイト

- [ローカル環境にTiDBを構築してみた。](https://zenn.dev/taki8545/articles/6fd377ef9bd883)

## minikube

### minikubeの設定

```sh
minikube delete
minikube start --cpus 4 --memory 6144
minikube status
kubectl cluster-info
```

## TiDB

### TiDB Operatorのデプロイ

- [Deploy TiDB Operator](https://docs.pingcap.com/tidb-in-kubernetes/stable/deploy-tidb-operator/)

#### CRDの作成

```sh
# kubectl apply -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.3.9/manifests/crd.yaml
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.5/manifests/crd.yaml
k get crd
```

#### TiDB Operatorのデプロイ

```sh
# PingCAPのリポジトリを追加
helm repo add pingcap https://charts.pingcap.org/
# TiDB Operatorの名前空間を作成
kubectl create namespace tidb-admin

# tidb-operator install
chart_version=v1.6.5
helm inspect values pingcap/tidb-operator --version=${chart_version} > ./tidb-operator/values-tidb-operator.yaml
helm install tidb-operator pingcap/tidb-operator --namespace=tidb-admin --version=${chart_version} -f ./tidb-operator/values-tidb-operator.yaml
kubectl get po -n tidb-admin -l app.kubernetes.io/name=tidb-operator

# OR
# tidb-operator install
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.3.9

```

### TiDBを作成

- [Kubernetes 上で TiDB クラスターを構成する](https://docs.pingcap.com/tidb-in-kubernetes/stable/configure-a-tidb-cluster/)

```sh
k create ns sample
k apply -n sample -f sample-tidb-cluster.yaml
k get pod -n sample

```

### mysqlクライアント接続確認

```sh
kubectl get svc -n sample
# -hはLoadBalancerのNAME
kubectl run -n sample -it --rm mysql-client --image=mysql:5.7 --restart=Never -- mysql -h sample-cluster-tidb -P 4000 -u root
```

mysql>プロンプトでの入力
```SQL
status
SELECT USER(), DATABASE();
show databases;
SHOW PROCESSLIST;
```

### 破壊実験

#### ポッド強制終了

```sh
k get pod -n sample -w
```
```sh
k delete pod -n sample sample-cluster-tikv-2 --force
k delete pod -n sample sample-cluster-tidb-2 --force
k delete pod -n sample sample-cluster-pd-2 --force
kubectl logs -n sample -l app.kubernetes.io/component=pd
```

連続SQL実行１
```sh
watch -n 1 'kubectl run -n sample -it --rm mysql-client --image=mysql:5.7 --restart=Never -- mysql -h sample-cluster-tidb -P 4000 -u root -e "SELECT NOW(), COUNT(*) FROM information_schema.tables;"'
```

連続SQL実行２
```sh
kubectl run -n sample mysql-client --image=mysql:5.7 -- sleep infinity
# 2. ポッドの中で無限ループを実行
kubectl exec -n sample -it mysql-client -- bash -c "
while true; do 
  mysql -h sample-cluster-tidb -P 4000 -u root -e 'SELECT NOW(), COUNT(*) FROM information_schema.tables;' 2>/dev/null; 
  if [ \$? -ne 0 ]; then
    echo \"\$(date): Connection failed\"
  fi
  sleep 1; 
done"

```

#### データファイル破壊1/ ローカルminikube環境

```sh
# TiKVのPVCとデータディレクトリを確認
kubectl get pvc -n sample
kubectl describe pvc -n sample
```

#### a) PVC内のデータファイルを直接破壊

```sh
# minikubeにSSH接続
minikube ssh

# TiKVのデータディレクトリを探す
sudo find /tmp/hostpath-provisioner -name "*.sst" -o -name "MANIFEST*"

# RocksDBのSSTファイルを破壊
sudo dd if=/dev/urandom of=/tmp/hostpath-provisioner/sample/tikv-sample-cluster-tikv-0/db/*.sst bs=1024 count=100

# MANIFESTファイルを削除
sudo rm /tmp/hostpath-provisioner/sample/tikv-sample-cluster-tikv-0/db/MANIFEST-*
```

b) ディスクフル実験

```sh
minikube ssh
# TiKVのデータディレクトリにダミーファイルを大量作成
sudo dd if=/dev/zero of=/tmp/hostpath-provisioner/sample/tikv-sample-cluster-tikv-0/fillup bs=1M count=8000
```

### 破壊実験3. カオスメッシュを使った本格的な障害注入（推奨）

```sh
# Chaos Meshのインストール

# CRDのインストール（server-side applyでannotation制限を回避）
kubectl apply --server-side -f https://mirrors.chaos-mesh.org/v2.5.0/crd.yaml

# Helmリポジトリ追加
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# minikubeのランタイムを確認
minikube ssh -- docker ps > /dev/null 2>&1 && echo "Runtime: Docker" || echo "Runtime: containerd"

# Dockerランタイムの場合（minikubeのデフォルト）
helm uninstall chaos-mesh -n chaos-testing 2>/dev/null || true
helm install chaos-mesh chaos-mesh/chaos-mesh \
  -n chaos-testing --create-namespace \
  --set chaosDaemon.runtime=docker \
  --set chaosDaemon.socketPath=/var/run/docker.sock \
  --set chaosDaemon.hostNetwork=true \
  --set dashboard.create=true

# containerdランタイムの場合
# helm install chaos-mesh chaos-mesh/chaos-mesh \
#   -n chaos-testing --create-namespace \
#   --set chaosDaemon.runtime=containerd \
#   --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
#   --set chaosDaemon.hostNetwork=true \
#   --set dashboard.create=true

# インストール確認
kubectl get pods -n chaos-testing
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=chaos-daemon -n chaos-testing --timeout=120s

# hostNetworkが有効か確認
kubectl get pod -n chaos-testing -l app.kubernetes.io/component=chaos-daemon -o jsonpath='{.items[0].spec.hostNetwork}'
# "true" と表示されればOK
```


```sh
# IOエラーを注入するYAMLを作成
cat > iochaos-tidb.yaml << 'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-delay-tikv
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
  errno: 5  # EIO (Input/output error)
  percent: 50
  duration: "30s"
EOF

kubectl apply -f iochaos-tidb.yaml
```

#### Chaos Mesh確認

```sh
# 1. IOChaosの状態を確認
kubectl describe iochaos -n sample io-delay-tikv

# 2. どのPodに障害が注入されたか確認
kubectl get iochaos -n sample io-delay-tikv -o jsonpath='{.status.experiment.containerRecords}'

# 3. TiKV-1のログを確認（I/Oエラーが出ているはず）
kubectl logs -n sample sample-cluster-tikv-1 --tail=50

# 4. PD-2のログを確認（クラッシュの原因）
kubectl logs -n sample sample-cluster-pd-2 --tail=50

# 5. TiDBから見たクラスターの状態を確認
kubectl exec -n sample -it mysql-client -- mysql -h sample-cluster-tidb -P 4000 -u root -e "
SELECT STORE_ID, ADDRESS, STORE_STATE_NAME, AVAILABLE 
FROM INFORMATION_SCHEMA.TIKV_STORE_STATUS;
"

# 6. SQLクエリが実行できるか試す
kubectl exec -n sample -it mysql-client -- mysql -h sample-cluster-tidb -P 4000 -u root -e "
SELECT NOW(), COUNT(*) FROM information_schema.tables;
"
```

#### Chaos実験の自動監視スクリプト

```sh
# スクリプトに実行権限を付与
chmod +x monitor-chaos.sh run-chaos-experiment.sh

# 方法1: 監視スクリプトのみ実行（手動でChaosを注入する場合）
./monitor-chaos.sh

# 方法2: 実験と監視を自動実行（推奨）
./run-chaos-experiment.sh
# メニューから実験タイプを選択:
# 1) 短期IOChaos (30秒, 50%エラー率)
# 2) 長期IOChaos (5分, 50%エラー率)
# 3) 高負荷IOChaos (2分, 100%エラー率)
# 4) I/O遅延 (2分, 100ms遅延)
# 5) Pod障害 (1分)
# 6) Pod強制終了
# 7) ネットワーク遅延 (200ms, 2分)
# 8) CPUストレス (2分)
```

監視スクリプトの出力例：
```
Time                | Status | Response                       | Pod Status
---------------------------------------------------------------------------------------------------
2026-02-13 12:00:01 | OK     | Tables: 123                    |        All Running (0 restarts)
2026-02-13 12:00:03 | OK     | Tables: 123                    |        All Running (0 restarts)
2026-02-13 12:00:05 | ERROR  | Lost connection to MySQL       | CHANGED [tikv-1:CrashLoopBackOff:1]
2026-02-13 12:00:07 | ERROR  | Can't connect to MySQL         |        [tikv-1:CrashLoopBackOff:1]
2026-02-13 12:00:35 | OK     | Tables: 123                    | CHANGED All Running (1 restarts)

--- Statistics (10 iterations) ---
Success: 7, Errors: 3
Availability: 70.00%
IOChaos: INACTIVE (正常状態)
```

#### 障害の手動注入

```sh
cd chaos
```

##### IOChaos

```sh
kubectl apply -f iochaos-tidb.yaml
```



## TiDB Cloud

https://tidbcloud.com/


```sh
kubectl run mysql-client --image=mysql:5.7 --restart=Never -- sleep 10000
kubectl cp isrgrootx1.pem mysql-client:/tmp/tidbcloud.pem
kubectl cp transactions_utf8.csv mysql-client:/tmp/transactions_utf8.csv
kubectl exec -it mysql-client -- bash

mysql --comments -u 'fugafuga.root' -h gateway01.ap-northeast-1.prod.aws.tidbcloud.com -P 4000 -D 'moneyforward' --ssl-mode=VERIFY_IDENTITY --ssl-ca=/tmp/tidbcloud.pem -p'hogehoge' --local-infile=1

load data local infile '/tmp/transactions_utf8.csv'
into table mf_transactions
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore
;
```


### Client Secret & Pod

```sh
kubectl create secret generic tidb-config --from-env-file=.env
kubectl create secret generic tidb-ca --from-file=ca.pem=isrgrootx1.pem
k create -f tidb-client.yaml
kubectl cp isrgrootx1.pem tidb-client:/tmp/tidbcloud.pem
kubectl cp transactions_utf8.csv tidb-client:/tmp/transactions_utf8.csv
kubectl exec -it tidb-client -- bash
mysql --comments -u "${TIDB_USER}" -h "${TIDB_HOST}" -P 4000 -D "${TIDB_DATABASE}" --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/tidb-ca/ca.pem -p"${TIDB_PASSWORD}" --local-infile=1

```

### Money Forward

#### 一括投入

1. マージファイル作成
```sh
CSV_DIR="/mnt/g/マイドライブ/life/家計/マネーフォワード/2024/"
for f in "${CSV_DIR}/"*.csv; do
  tail -n +2 "$f" | iconv -f sjis -t utf-8
done > transactions.csv
# 確認
# find ${CSV_DIR} -maxdepth 1 -name "*.csv" -exec tail -n +2 {} + | wc -l
file transactions.csv  # UTF-8であることを確認
wc -l transactions.csv  # 行数を確認
```

2. 投入
```sh
k create -f tidb-client.yaml
kubectl cp transactions.csv tidb-client:/tmp/transactions.csv
kubectl exec -it tidb-client -- bash
mysql --comments -u "${TIDB_USER}" -h "${TIDB_HOST}" -P 4000 -D "${TIDB_DATABASE}" --ssl-mode=VERIFY_IDENTITY --ssl-ca=/etc/tidb-ca/ca.pem -p"${TIDB_PASSWORD}" --local-infile=1
truncate table mf_transactions;
load data local infile '/tmp/transactions.csv'
ignore
into table mf_transactions
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
;
```

### 自動投入

#### 構想

- K8SのJOBとして動作する
- 引数に年月とCSVファイル名を渡す
- mf_transactionsテーブルの当該年月のデータを入れ替える（DELETEしてLOAD）
- CSVファイルをUTF-8に変換するJOBと、CSVをロードするJOBに分ける。
- CSVファイルをGoogle Driverからローカルに持ってくるジョブもPODにする

#### 環境

```sh
k create ns mf
kubectl create secret generic tidb-config --from-env-file=../../.env -n mf
kubectl create secret generic tidb-ca --from-file=ca.pem=../../isrgrootx1.pem -n mf
```

## etc

Google Drive 手動マウント
```sh
sudo mount -t drvfs G: /mnt/g
```