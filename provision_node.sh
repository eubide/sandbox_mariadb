#!/bin/bash

# https://severalnines.com/blog/updated-how-bootstrap-mysql-or-mariadb-galera-cluster

# yum  -y update

iptables -F
setenforce 0

NODE_NR=$1
NODE_IP="$2"
IPS_COMMA="$3"
BOOTSTRAP_IP="$4"

tee /etc/yum.repos.d/MariaDB.repo<<EOF 
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.4/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

yum makecache fast

yum -y install MariaDB-server MariaDB-client 

tee /etc/my.cnf.d/galera.cnf<<EOF
[mysqld]

binlog_format = ROW
default_storage_engine = innodb
innodb_autoinc_lock_mode = 2
bind_address = 0.0.0.0

innodb_locks_unsafe_for_binlog = 1
innodb_autoinc_lock_mode = 2
innodb_file_per_table = 1
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_buffer_pool_size = 512M
innodb_use_native_aio = 0

server_id = $NODE_NR
log_error = mariadb${NODE_NR}.err
binlog_format = ROW

# Galera Provider Configuration
wsrep_on = ON
wsrep_provider = /usr/lib64/galera-4/libgalera_smm.so

wsrep_provider_options = "gcs.fc_limit=500; gcs.fc_master_slave=YES; gcs.fc_factor=1.0; gcache.size=256M;"
wsrep_slave_threads = 1
wsrep_auto_increment_control = ON

# Galera Cluster Configuration
wsrep_cluster_name=db_cluster
wsrep_cluster_address=gcomm://$IPS_COMMA
wsrep_node_address=$NODE_IP
wsrep_node_name=node$NODE_NR

# Galera Synchronization Configuration
wsrep_sst_method=rsync
# Can use mariabackup: apt install mariadb-backup
# https://mariadb.com/kb/en/library/mariadb-backup-overview/#using-mariadb-backup-for-galera-ssts
#wsrep_sst_method=mariabackup
#wsrep_sst_auth=USER:PASSWORD
EOF

# systemctl enable --now mariadb

if [[ $NODE_NR -eq 1 ]]
then
	galera_new_cluster

	# ProxySQL users
	mysql -e "CREATE USER 'monitor'@'%' IDENTIFIED BY 'monit0r';"
	mysql -e "GRANT USAGE ON *.* TO 'monitor'@'%';"
	mysql -e "CREATE USER 'monitor'@'localhost' IDENTIFIED BY 'monit0r';"
	mysql -e "GRANT USAGE ON *.* TO 'monitor'@'localhost';"
	mysql -e "CREATE USER 'app'@'%' IDENTIFIED BY 'app';"
	mysql -e "GRANT ALL ON *.* TO 'app'@'%';"
	mysql -e "CREATE USER 'app'@'localhost' IDENTIFIED BY 'app';"
	mysql -e "GRANT ALL ON *.* TO 'app'@'localhost';"

	mysql -e "grant all privileges on *.* to 'root'@'192.%' identified by 'sekret';"
	mysql -e "grant all privileges on *.* to 'root'@'127.0.0.1' identified by 'sekret';"
	mysql -e "grant all privileges on *.* to 'root'@'localhost' identified by 'sekret';"

else
	for i in {1..60}
	do
		MYSQLADMIN=`mysqladmin -uroot -psekret -h$BOOTSTRAP_IP ping`
		if [[ "$MYSQLADMIN" == "mysqld is alive" ]]
		then 
			systemctl start mariadb
			exit
		else
			sleep 5
		fi
	done
fi
