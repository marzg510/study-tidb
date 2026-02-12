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
k create -f tidb-client.yaml
kubectl cp isrgrootx1.pem tidb-client:/tmp/tidbcloud.pem
kubectl cp transactions_utf8.csv tidb-client:/tmp/transactions_utf8.csv
kubectl exec -it tidb-client -- bash
mysql --comments -u "${TIDB_USER}" -h "${TIDB_HOST}" -P 4000 -D "${TIDB_DATABASE}" --ssl-mode=VERIFY_IDENTITY --ssl-ca=/tmp/tidbcloud.pem -p"${TIDB_PASSWORD}" --local-infile=1

```

