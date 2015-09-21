#!/usr/bin/bash
###################################################################################
# Arkadiusz Karol Borucki
# 
# Job run at 8 AM
###################################################################################
# set profile
. $HOME/.profile
###################################################################################
DATE=`date +%Y%m%d%H%M`
LOGFILE=/export/home/oracle/log/`basename $0`_${DATE}.log
DIAG=/export/home/oracle/log/`basename $0`_${DATE}_DIAG.log
######################################################################################################################################################################
########### MAIL
######################################################################################################################################################################
mailx -s "HDT sdb106f1 10" monitoring@xxxx.com <<_EOF_
Neuaufbau der sdb103f0
_EOF_

default_error_msg ()
{
EMPFAENGER='arkadiusz.borucki@xxxx.com,'
BETREFF="IEMM Something goes wrong - go to ALERT logs "
NACHRICHT="Go to ALERT logs

 `cat $LOGFILE`
-----------------------------------------------------------------------------
"
send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"
}

###################################################################################
###################################################################################

$ORACLE_HOME/bin/sqlplus / as sysdba@IEMM << _EOF_ >> $LOGFILE
set pagesize 300
set linesize 300
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER DATABASE STOP LOGICAL STANDBY APPLY;
create restore point after_stop_apply guarantee flashback database;
alter database guard none;
exit;
_EOF_
if [[ $? != 0 ]]; then

   echo "error  $?"

   default_error_msg

fi

$ORACLE_HOME/bin/sqlplus / as sysdba@IEMM << _EOF_ >> $DIAG
set pagesize 300
set linesize 300
WHENEVER SQLERROR EXIT SQL.SQLCODE
select status from v\$instance;
select * from v\$dataguard_stats;
select GUARD_STATUS from v\$database;
exit;
_EOF_

if [[ $? != 0 ]]; then

   echo "error  $?"

   default_error_msg

fi

FILE=$(cat $LOGFILE | grep -i error | wc -l )
echo $FILE

if [[ $FILE -gt 0 ]]; then

NACHRICHT="Go to $LOGFILE
contents of error log:
`cat $LOGFILE`
-----------------------------------------------------------------------------

 

 

 

 ------------------------------------------------------------------------------
"
BETREFF="IEMM Something goes wrong "
EMPFAENGER='arkadiusz.borucki@db-is.com,IT-OPS.Database@db-is.com'
send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"

fi
