#!/bin/bash
export ORACLE_HOME=/usr/lib/oracle/xe/app/oracle/product/10.2.0/server
export ORACLE_SID=XE
cd /var/www/lighttpd/munshi9/restore/
/bin/gunzip latest.dmp.gz
/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/bin/imp munshi8/gbaba4000 file=latest.dmp fromuser=munshi8 commit=y
rm latest.dmp
