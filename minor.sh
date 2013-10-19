#!/bin/bash
export ORACLE_HOME=/usr/lib/oracle/xe/app/oracle/product/10.2.0/server
export ORACLE_SID=XE
cd /var/www/lighttpd/munshi9
/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/bin/sqlplus munshi8/gbaba4000 @http://mavsol.com/munshi9/minor.sql
