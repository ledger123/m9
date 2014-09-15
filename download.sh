#!/bin/bash
rm munshi9.sql
rm munshi9.sql.zip
wget http://www.mavsol.com/munshi9/munshi9.sql.zip
unzip munshi9.sql.zip
sqlplus munshi8/gbaba4000 @munshi9.sql
