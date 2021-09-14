#!/bin/bash
# https://severalnines.com/blog/updated-how-bootstrap-mysql-or-mariadb-galera-cluster

echo "---"
echo "provision_node.sh: arguments revieved $@"

NODE_NR=$1
NODE_IP="$2"
IPS_COMMA="$3"
BOOTSTRAP_IP="$4"

iptables -F
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

cat <<EOF >/etc/environment
LANG=en_US.utf-8
LC_ALL=en_US.utf-8
LC_CTYPE=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd.service

# more versions on http://yum.mariadb.org/
VERSION=10.4.19
# VERSION=10.1

cat <<EOF | sudo tee -a /etc/yum.repos.d/MariaDB.repo
# MariaDB 10.1 CentOS repository list
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/${VERSION}/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

yum makecache fast

yum -y install MariaDB-server MariaDB-client MariaDB-backup

yum -y install wget tar perf gdb strace vim socat
yum -y install sysbench

yum -y install https://downloads.percona.com/downloads/percona-toolkit/3.3.1/binary/redhat/7/x86_64/percona-toolkit-3.3.1-1.el7.x86_64.rpm

tee /etc/my.cnf.d/galera.cnf <<EOF
[mysqld]

binlog_format                  = ROW
default_storage_engine         = innodb
bind_address                   = 0.0.0.0

innodb_locks_unsafe_for_binlog = 1
innodb_autoinc_lock_mode       = 2
innodb_file_per_table          = 1
innodb_log_file_size           = 256M
innodb_flush_log_at_trx_commit = 2
innodb_buffer_pool_size        = 256M
innodb_use_native_aio          = 0

server_id                      = $NODE_NR
log_error                      = node${NODE_NR}.err

log_warnings                   = 1

# slow queries for PMM 
log_output                     = file
slow_query_log                 = ON
long_query_time                = 0
log_slow_verbosity             = query_plan,innodb
log_slow_admin_statements      = ON
log_slow_slave_statements      = ON
innodb_monitor_enable          = all
userstat                       = 1
performance_schema             = ON

# Galera Provider Configuration
wsrep_on                       = ON
wsrep_provider                 = /usr/lib64/galera-4/libgalera_smm.so

# mariadb 10.3 --- mariadb-backup is not working with mysql user
# wsrep_provider               = /usr/lib64/galera/libgalera_smm.so


wsrep_provider_options         = "gcs.fc_limit=100; gcs.fc_master_slave=YES; gcs.fc_factor=1.0; gcache.size=125M;"
wsrep_slave_threads            = 1
wsrep_auto_increment_control   = ON

# Galera Cluster Configuration
wsrep_cluster_name             = db_cluster
wsrep_cluster_address          = gcomm://$IPS_COMMA
wsrep_node_address             = $NODE_IP
wsrep_node_name                = node$NODE_NR

# Galera Synchronization Configuration - RSYNC
# wsrep_sst_method             = rsync

# Galera Synchronization Configuration - MARIADB-BACKUP 
wsrep_sst_method               = mariabackup
wsrep_sst_auth                 = mysql
# wsrep_sst_auth               = mariadb:mar1ab4ckup

[sst]
sst-log-archive                = 1
# sst-log-archive-dir          = /var/log/
EOF

# systemctl enable --now mariadb

if [[ $NODE_NR -eq 1 ]]; then
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

  mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'192.%' IDENTIFIED BY 'sekret';"
  mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY 'sekret';"
  mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'sekret';"

else
  for i in {1..60}; do
    MYSQLADMIN=$(mysqladmin -uroot -psekret -h"$BOOTSTRAP_IP" ping)
    if [[ "$MYSQLADMIN" == "mysqld is alive" ]]; then
      systemctl start mariadb
      echo "ready on $i"
      exit
    else
      sleep 5
    fi
  done
fi

cat <<EOF >/home/vagrant/.my.cnf
[mysql]
user=root
password=sekret
socket=/var/lib/mysql/mysql.sock
EOF
