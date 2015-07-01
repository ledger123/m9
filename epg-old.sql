execute dbms_epg.drop_dad('olddata');

execute DBMS_EPG.CREATE_DAD(dad_name => 'olddata', path => '/olddata/*');

execute DBMS_EPG.SET_DAD_ATTRIBUTE('olddata', 'default-page', 'a$main.menu');

execute DBMS_EPG.set_dad_attribute('olddata', 'database-username', 'OLDDATA');
execute dbms_epg.authorize_dad('olddata', 'OLDDATA');
