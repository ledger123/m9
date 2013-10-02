------------------------------------------------------
--                                                  --
-- M. Armaghan Saqib                                --
--                                                  --
-- Email: armaghan@yahoo.com                        --
--                                                  --
-- http://www.geocities.com/armaghan/               --
--                                                  --
------------------------------------------------------
SET HEADING OFF
SET PAGESIZE 0
SET TERMOUT OFF
SET FEEDBACK OFF
SET TRIMSPOOL ON
SET LINESIZE 2000
SPOOL output.sql
SELECT text FROM sqlpp_output ORDER BY line;
DELETE FROM sqlpp_output; 
COMMIT;
---
--- You should use following statements instead of the above ones
--- if more then one user connect to same DATABASE USER.
---
-- SELECT text FROM sqlpp_output WHERE (sessionid = USERENV('SESSIONID')) ORDER BY line;
-- DELETE FROM sqlpp_output WHERE (sessionid = USERENV('SESSIONID'));
--
SPOOL OFF
SET TERMOUT ON
SET FEEDBACK ON
SET HEADING ON
ED output.sql
