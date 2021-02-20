#!/bin/bash

cat <<EOF | tee /etc/yum.repos.d/proxysql.repo
[proxysql_repo]
name= ProxySQL YUM repository
baseurl=https://repo.proxysql.com/ProxySQL/proxysql-2.0.x/centos/\$releasever
gpgcheck=1
gpgkey=https://repo.proxysql.com/ProxySQL/repo_pub_key
EOF

yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm

yum -y install wget tar strace vim proxysql-2.0.16 Percona-Server-client-57 sysbench

iptables -F
setenforce 0

cat <<EOF >/etc/environment
LANG=en_US.utf-8
LC_ALL=en_US.utf-8
EOF

systemctl start proxysql
sleep 7

# vagrant user custom .bashrc
cat <<EOF >>/home/vagrant/.bashrc
alias admin='mysql -u admin -padmin -h 127.0.0.1 -P6032 --prompt="proxysql> "'
EOF

MYSQL="mysql -uadmin -padmin -h127.0.0.1 -P6032 "

$MYSQL <<EOF
-- MYSQL INTERFACE

show variables like '%interface%';
UPDATE global_variables SET variable_value='0.0.0.0:3306' WHERE variable_name='mysql-interfaces';
SAVE MYSQL VARIABLES TO DISK;
EOF

systemctl restart proxysql
sleep 7

$MYSQL <<EOF
-- ADMIN VARIABLES

UPDATE global_variables SET variable_value='admin:admin;cluster_user:cluster_password' WHERE variable_name = 'admin-admin_credentials';
UPDATE global_variables SET variable_value='cluster_user' WHERE variable_name = 'admin-cluster_username';
UPDATE global_variables SET variable_value='cluster_password' WHERE variable_name = 'admin-cluster_password';

LOAD ADMIN VARIABLES TO RUNTIME;SAVE ADMIN VARIABLES TO DISK;

-- MONITOR VARIABLES
UPDATE global_variables SET variable_value='monit0r' WHERE variable_name='mysql-monitor_password';
UPDATE global_variables SET variable_value='2000' WHERE variable_name IN ('mysql-monitor_connect_interval','mysql-monitor_ping_interval','mysql-monitor_read_only_interval');

LOAD MYSQL VARIABLES TO RUNTIME;SAVE MYSQL VARIABLES TO DISK;
EOF

WRITE_NODE=""
NODES=$1
shift

# Users
mysql -h "$1" -u root -psekret -NB mysql <<EOF >/tmp/users.sql
select distinct "INSERT INTO mysql_users (username,password,default_hostgroup) VALUES (", CONCAT("'",User,"'"), ",", CONCAT("'",Password,"'"), ",10);" 
from user WHERE password LIKE "*%" and User not in ('root','monitor') order by User;
EOF

$MYSQL </tmp/users.sql
$MYSQL -e "LOAD MYSQL USERS TO RUN; SAVE MYSQL USERS TO DISK;"

# for each Galera node
for node in $(seq 1 "$NODES"); do
	if [[ $node -gt 1 ]]; then
		WRITE_NODE+=","
	fi
	WRITE_NODE+="$1:3306"
	$MYSQL -e "INSERT INTO mysql_servers(hostgroup_id,hostname) VALUES(10,'$1');"
	shift
done
$MYSQL -e "LOAD MYSQL SERVERS TO RUN; SAVE MYSQL SERVERS TO DISK;"

$MYSQL -e "INSERT INTO mysql_galera_hostgroups (writer_hostgroup,backup_writer_hostgroup,reader_hostgroup,offline_hostgroup,active,max_writers,writer_is_also_reader,max_transactions_behind) 
VALUES (10,30,20,40,1,1,1,100);"
$MYSQL -e "LOAD MYSQL SERVERS TO RUN; SAVE MYSQL SERVERS TO DISK;"

$MYSQL <<EOF
DELETE FROM mysql_query_rules; 
INSERT INTO mysql_query_rules (rule_id, active, match_digest, destination_hostgroup, apply) VALUES (1, 1, '^SELECT.* FOR UPDATE', 10, 1);
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) VALUES (2, 1, '.*/\* RO \*/.*', 20, 1);
INSERT INTO mysql_query_rules (rule_id, active, match_digest, destination_hostgroup, apply) VALUES (3, 1, '^SELECT.*', 20, 1);
LOAD MYSQL QUERY RULES TO RUNTIME;SAVE MYSQL QUERY RULES TO DISK;
EOF

# cluster proxysql config
# for each ProxySQL node

PROXYSQL_NODES="$1"
shift

if [[ $PROXYSQL_NODES -gt 1 ]]; then
	for proxy in $(seq 1 "$PROXYSQL_NODES"); do
		$MYSQL -e "INSERT INTO proxysql_servers VALUES ('$1',6032,0,'proxysql$proxy');"
		shift
	done
	$MYSQL -e "LOAD PROXYSQL SERVERS TO RUNTIME; SAVE PROXYSQL SERVERS TO DISK;"
fi
