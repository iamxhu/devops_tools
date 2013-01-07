#!/bin/bash
# 
# File: find_mysql_spaceids.sh
#
# Author: huxing1985@gmail.com
# blog: www.colorfuldays.org
# 
# Purpose: This script is a part of a tool recover mysql data from .frm and .idb file.
# step 1. read files under <idbfiledir>,find the "space id",
#         export an file spaceids.txt as "<idb_file_name>  space_id".
# step 2. use the spaceids.txt sort by space_id asc,
#         then generate a script which is use to export the table's create script named export_table_schema.sh. 
#         if there aren't serial space id , the script will fill it with create tmp table sql in test database.
# step 3. generate a script dump the table file to a file named as <table_name>.data.
# 
# export_table_schema.sh use to export table schema after recovery the table schema use frm file.
# export_table_schema.sh use to export table data after recovery table data use idb file.
# 

if [[ $# -lt 3 ]]; then
    echo "find_mysql_spaceids.sh <datafiledir> <dbuser> <dbpasswd> <dbname>"
fi

datafile=$1
user=$2
passwd=$3
dbname=$4

for i in `find $datafile -name "*.ibd"`
do
    hex=`hexdump -C $i | head -n 3 | tail -n 1 | awk '{print $6$7}'`
    echo $i " " $((16#$hex)) >> spaceids.txt
done

# init file create_table.sql 
if [[ -f create_table.sql ]]; then
    echo "" > create_table.sql
fi

if [[ -f export_table_schema.sh ]]; then
    echo "" > export_table_schema.sh
fi

if [[ -f export_table_data.sh ]]; then
    echo "" > export_table_data.sh
fi

last_space_id=1
for i in `cat spaceids.txt | sort -k 2 | awk -F "/" '{print $NF}' ` 
do
    if [[ "x$i" != "x" ]]; then
        new_space_id=`awk '{print $2}' $i`;
        tablename=`awk -F "." '{print $1}' $i`
        if [[ $last_space_id -gt 1 ]]; then
            margin=`expr $new_space_id - $last_space_id`
            for (( a = 1; a < $margin; a++ )); do
                echo 'mysql -u'$user'-p'$passwd' -s -e "use test; CREATE TABLE fill_table'$i' (id bigint(20) NOT NULL AUTO_INCREMENT,PRIMARY KEY (id)) ENGINE=innodb;" >> create_table.sql' >> export_table_schema.sh
            done
        fi

        echo 'mysql -u'$user'-p'$passwd' -s -e "use '$dbname'; show create table '$tablename';" >> create_table.sql' >> export_table_schema.sh
        echo 'mysql -u'$user'-p'$passwd' -s -e "use '$dbname'; select * from '$tablename' into '$tablename'.data;" ' >> export_table_data.sh
    fi
done

