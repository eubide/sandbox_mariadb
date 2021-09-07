#!/bin/bash

. ./sysbench_config

sysbench \
	--db-driver=mysql \
	--mysql-user=${SYSB_USER} \
	--mysql_password=${SYSB_PASS} \
	--mysql-db=${SYSB_DB} \
	--mysql-host=${HOST_IP} \
	--mysql-port=${HOST_PORT} \
	--tables=${TABLES} \
	--table-size=${TABLE_SIZE} \
	/usr/share/sysbench/${TYPE} \
	prepare
