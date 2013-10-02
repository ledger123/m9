------------------------------------------------------
--                                                  --
-- M. Armaghan Saqib                                --
--                                                  --
-- Email: armaghan@yahoo.com                        --
--                                                  --
-- http://www.geocities.com/armaghan/               --
--                                                  --
------------------------------------------------------
SET SERVEROUTPUT ON SIZE 1000000;
SET HEADING OFF
SET PAGESIZE 0
SET TERMOUT OFF
SET FEEDBACK OFF
SET TRIMSPOOL ON
SET LINESIZE 2000

SPOOL multi.sql;
BEGIN
   dbms_output.put_line('SET HEADING OFF');
   dbms_output.put_line('SET PAGESIZE 0');
   dbms_output.put_line('SET TERMOUT OFF');
   dbms_output.put_line('SET FEEDBACK OFF');
   dbms_output.put_line('SET TRIMSPOOL ON');
   dbms_output.put_line('SET LINESIZE 2000');
   DECLARE cursor c IS 
      SELECT DISTINCT file_name FROM sqlpp_output;
   BEGIN
      FOR r IN c LOOP
        dbms_output.put_line('--');
        dbms_output.put_line('-- Create ' || r.file_name);
        dbms_output.put_line('--');
        dbms_output.put_line('SPOOL ' || r.file_name);
        dbms_output.put_line('SELECT text FROM sqlpp_output');
        dbms_output.put_line('  WHERE (file_name = ''' || r.file_name || ''')');
        dbms_output.put_line('    AND (owner = USER)');
        -- dbms_output.put_line('    AND (sessionid = USERENV(''SESSIONID''))');
        dbms_output.put_line('  ORDER BY line;');
        dbms_output.put_line('SPOOL OFF');
      END LOOP;
   END;
   dbms_output.put_line('SET TERMOUT ON');
   dbms_output.put_line('DELETE FROM sqlpp_output WHERE (owner = USER);');
   dbms_output.put_line('COMMIT;');
END;
/
SPOOL OFF
@multi.sql
