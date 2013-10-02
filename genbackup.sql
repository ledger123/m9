SET HEADING OFF
SET WARNING OFF
SET LINESIZE 200
SET TRIMSPOOL ON
SET DEFINE ON
SET ECHO OFF
SET FEEDBACK OFF
SET VERIFY OFF

COL client_name FOR A30 NEW_VALUE client_name
SELECT LOWER(global_value) client_name FROM z_apps_data WHERE id='CLIENT_NAME';

SPOOL dobackup.sh
SELECT '#!/bin/bash' FROM dual;
SELECT '/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/bin/exp munshi8/gbaba4000 file=&client_name.-' || TO_CHAR(SYSDATE, 'YYYY-MM-DD-HH24MI') || '.dmp STATISTICS=NONE'
FROM dual;
SELECT 'rm &client_name.-' || TO_CHAR(SYSDATE, 'YYYY-MM-DD-HH24MI') || '.dmp.gz &client_name..gz' FROM dual;
SELECT '/bin/gzip &client_name.-' || TO_CHAR(SYSDATE, 'YYYY-MM-DD-HH24MI') || '.dmp' FROM dual;
SELECT 'cp &client_name.-' || TO_CHAR(SYSDATE, 'YYYY-MM-DD-HH24MI') || '.dmp.gz &client_name..dmp.gz' FROM dual;
SELECT '/usr/bin/rsync -arvz -e ssh &client_name..dmp.gz mavsol@mavsol.strongspace.com:backup2013/munshi9/' FROM dual;
QUIT
