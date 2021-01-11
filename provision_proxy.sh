#!/bin/bash
echo "1: $1"

yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm

yum -y install wget tar strace vim proxysql Percona-Server-client-57
#yum -y install tar strace vim Percona-Server-client-57 proxysql-1.3.7-1.1.el7.x86_64
#yum -y install tar strace vim Percona-Server-client-57 proxysql-1.4.5-1.1.el7
#yum -y install tar strace vim Percona-Server-client-57 https://github.com/sysown/proxysql/releases/download/v1.4.8/proxysql-1.4.8-1-centos7.x86_64.rpm
iptables -F
setenforce 0

systemctl start proxysql
MYSQL="mysql -uadmin -padmin -h127.0.0.1 -P6032 -e "
sleep 7

$MYSQL "UPDATE global_variables SET variable_value='admin:admin;cluster_user:cluster_password' WHERE variable_name = 'admin-admin_credentials'"
$MYSQL "UPDATE global_variables SET variable_value='cluster_user' WHERE variable_name = 'admin-cluster_username';"
$MYSQL "UPDATE global_variables SET variable_value='cluster_password' WHERE variable_name = 'admin-cluster_password';"
$MYSQL "LOAD ADMIN VARIABLES TO RUNTIME;SAVE ADMIN VARIABLES TO DISK;"


#proxysql-admin --config-file=/etc/proxysql-admin.cnf --without-cluster-app-user --syncusers --write-node="$1:3306" --enable
WRITE_NODE=""
NODES=$1
shift


sed "s/CLUSTER_HOSTNAME='localhost'/CLUSTER_HOSTNAME='$1'/g" -i /etc/proxysql-admin.cnf
sed "s/CLUSTER_USERNAME='admin'/CLUSTER_USERNAME='app'/g" -i /etc/proxysql-admin.cnf
sed "s/CLUSTER_PASSWORD='admin'/CLUSTER_PASSWORD='app'/g" -i /etc/proxysql-admin.cnf


for node in $(seq 1 $NODES)
do
  if [[ $node -gt 1 ]]
  then
    WRITE_NODE+=","
  fi
  WRITE_NODE+="$1:3306"
  shift
done

PROXYSQL_NODES="$1"
shift
for proxy in $(seq 1 $PROXYSQL_NODES)
do
  $MYSQL "INSERT INTO proxysql_servers VALUES ('$1',6032,0,'proxysql-$proxy');"
  shift
done
$MYSQL "LOAD PROXYSQL SERVERS TO RUNTIME; SAVE PROXYSQL SERVERS TO DISK;"


# getting my version of the tool while the Pr isnt approved
#wget https://raw.githubusercontent.com/altmannmarcelo/proxysql-admin-tool/v1.4.9-dev/proxysql-admin -O /bin/proxysql-admin
proxysql-admin --config-file=/etc/proxysql-admin.cnf --without-cluster-app-user --syncusers --write-node="$WRITE_NODE" --enable
