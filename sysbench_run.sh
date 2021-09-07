#!/bin/bash

. ./sysbench_config

sysbench \
	--db-driver=mysql \
	--db-ps-mode=disable \
	--skip-trx \
	--mysql-user=${SYSB_USER} \
	--mysql_password=${SYSB_PASS} \
	--mysql-db=${SYSB_DB} \
	--mysql-host=${HOST_IP} \
	--mysql-port=${HOST_PORT} \
	--tables=${TABLES} \
	--table-size=${TABLE_SIZE} \
	--threads=${THREADS} \
	--mysql-ignore-errors=all \
	--time=0 \
	--events=0 \
	--report-interval=1 \
	/usr/share/sysbench/${TYPE} \
	run
