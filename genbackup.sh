#!/bin/bash
export ORACLE_HOME=/usr/lib/oracle/xe/app/oracle/product/10.2.0/server
export ORACLE_SID=XE
mkdir -p /var/www/lighttpd/munshi9/backups/
cd /var/www/lighttpd/munshi9/backups/
/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/bin/sqlplus munshi8/gbaba4000 @/var/www/lighttpd/munshi9/genbackup.sql
/bin/bash /var/www/lighttpd/munshi9/backups/dobackup.sh
