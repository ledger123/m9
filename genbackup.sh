#!/bin/bash
export ORACLE_HOME=/usr/lib/oracle/xe/app/oracle/product/10.2.0/server
export ORACLE_SID=XE
mkdir /root/backups/
cd /root/backups
/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/bin/sqlplus munshi8/gbaba4000 @/var/www/munshi9/genbackup.sql
/bin/bash /root/backups/dobackup.sh
