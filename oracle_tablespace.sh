#!/bin/bash
###############################################################################################
############## tablespaces.sh 18.01.2016, Arkadiusz Karol Borucki
############## script is checking Oracle tablespaces and returns three valuse - 0, 1, 2
############## 0 - normal
############## 1 - warning
############## 2 - critical
###############################################################################################
DBA="aborucki@xxxx"
ORACLE_SID="A"
 ORACLE_HOME="/Oracle/app/oracle/product/db11g"

fs_check()
{
$ORACLE_HOME/bin/sqlplus -S / as sysdba << eof |awk 'NF'| grep -v '[$a-z]' > /tmp/check_tablespace.temp
set pages 0
select free_percent, tablespace_name
from (
            SELECT b.tablespace_name, b.tablespace_size_mb, sum(nvl(fs.bytes,0))/1024/1024 free_size_mb,
            (sum(nvl(fs.bytes,0))/1024/1024/b.tablespace_size_mb *100) free_percent
            FROM dba_free_space fs,
                 (SELECT tablespace_name, sum(bytes)/1024/1024 tablespace_size_mb FROM dba_data_files
                  GROUP BY tablespace_name
                 ) b
           where
           fs.tablespace_name like '%'
           and
           fs.tablespace_name = b.tablespace_name
           group by b.tablespace_name, b.tablespace_size_mb
        ) ts_free_percent
WHERE free_percent < 15
ORDER BY free_percent;
exit
eof

chmod ugo+rw /tmp/check_tablespace.temp
counter=`cat /tmp/check_tablespace.temp | sed '/^$/d'| wc -l`
echo "count="$counter
#cat /tmp/check_tablespace.temp

if [ $counter -eq 0 ];then
echo "tablespaces ok, count="$counter
return 0
exit
fi

for i in `cat /tmp/check_tablespace.temp| awk '{print $1}'| cut -d'.' -f1`
do
echo "w petli" $i
if [[ $i -lt 6 ]]; then
echo "critical"
return 2
exit
else
echo "less than 15 - warning"
return 1
exit
fi
done

}

fs_check
