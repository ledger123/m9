execute dbms_epg.drop_dad('munshi9');

execute DBMS_EPG.CREATE_DAD(dad_name => 'munshi9', path => '/munshi9/*');

execute DBMS_EPG.SET_DAD_ATTRIBUTE('munshi9', 'default-page', 'a$main.menu');

execute DBMS_EPG.set_dad_attribute('munshi9', 'database-username', 'MUNSHI8');
execute dbms_epg.authorize_dad('munshi9', 'MUNSHI8');
