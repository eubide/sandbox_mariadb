#!/bin/bash

sysbench \
--db-driver=mysql \
--mysql-user=app \
--mysql_password=app \
--mysql-db=test \
--mysql-host=192.168.35.90 \
--mysql-port=3306 \
--tables=16 \
--table-size=10000 \
/usr/share/sysbench/oltp_read_write.lua prepare
