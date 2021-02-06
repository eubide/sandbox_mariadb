#!/bin/bash

sysbench \
--db-driver=mysql \
--mysql-user=app \
--mysql_password=app \
--mysql-db=test \
--mysql-host=192.168.35.90 \
--mysql-port=3306 \
--tables=8 \
--table-size=100000 \
--threads=24 \
--time=0 \
--events=0 \
--report-interval=1 /usr/share/sysbench/oltp_read_write.lua run