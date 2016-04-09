#!/usr/bin/bash
###################################################################################
# Arkadiusz Karol Borucki -  Job run at 4PM
# Script flashback database and enable Data Guard
###################################################################################

# set profile
. $HOME/.profile
ana=`id -p`
echo $ana

DATE=`date +%Y%m%d%H%M`
LOGFILE=/export/home/oracle/log/`basename $0`_${DATE}.log
DIAG=/export/home/oracle/log/`basename $0`_${DATE}_DIAG.log
######################################################################################################################################################################
########### MAIL
######################################################################################################################################################################
mailx -s "HDT sdb106f1 10" monitoring@xxxx.com <<_EOF_
Neuaufbau der sdb103f0
_EOF_

ABSENDER='noreply@xxxxx.com'
EMPFAENGER='arkadiusz.borucki@xxxxx.com'
DEVMAIL='arkadiusz.borucki@xxxxx.com'
NACHRICHT=" "
BETREFF="IEMM goes OFFLINE"

send_mail ()
{
SENDMAIL=/usr/sbin/sendmail
MAILFILE=/tmp/.tmp_mail.msg
ABSENDER="$1"
EMPFAENGER="$2"
BETREFF="$3"
NACHRICHT="$4"
PRIORITAET="$5"

if [[ -n $6 ]]; then

   CC="$6"

fi

if [[ -n $7 ]]; then

   BCC="IT-OPS.Database@xx-xx.xxx; $7"

fi

FUSSZEILE="------------------------------------------
Hello

IEMM goes offline

 
Thank you
DB team

Diese Mail wurde automatisch generiert von
$SKRIPT_NAME auf `hostname`"

 

case $PRIORITAET in

        [Hh]och )

 

HEADER="From: $ABSENDER

To: $EMPFAENGER

Cc: $CC
Bcc: $BCC
Subject: $BETREFF
Content-Type: text/plain;
X-Priority: 1 (Highest)
Priority: Urgent
Importance: High
X-MSMail-Priority: High"

        ;;

 

        * )

HEADER="From:noreply@xx-xx.xxx
To:$EMPFAENGER
Cc: $CC
Bcc: $BCC
Subject: $BETREFF

Content-Type: text/plain;"

esac

 
if [[ -f $MAILFILE ]]; then

   rm $MAILFILE

fi

cat >> $MAILFILE << EOF
$HEADER

-----------------------------------------

$NACHRICHT
$FUSSZEILE
EOF

$SENDMAIL -t < $MAILFILE

if [[ -f $MAILFILE ]]; then
rm $MAILFILE
echo ''
fi
}

###################################################################################
###################################################################################

send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"

###################################################################################
###################################################################################

default_error_msg ()

{
EMPFAENGER='arkadiusz.borucki@xx-xx.xxx,IT-OPS.Database@xx-xx.xxx'
BETREFF="IEMM Something goes wrong - go to ALERT logs "
NACHRICHT="Go to ALERT logs

`cat $LOGFILE`

-----------------------------------------------------------------------------
"

send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"

}

 
###################################################################################
############# Oracle startup mount
###################################################################################

echo  Oracle database startup mount
ORA_SID=$(echo $ORACLE_SID)
echo $ORA_SID
echo ------------------------------------------------------------------

$ORACLE_HOME/bin/sqlplus / as sysdba@IEMM << _EOF_ >> $LOGFILE
set pagesize 300
set linesize 300
WHENEVER SQLERROR EXIT SQL.SQLCODE

shutdown immediate;
startup mount;

exit;
_EOF_

if [[ $? != 0 ]]; then

   echo "error  $?"

   default_error_msg

fi

 

###################################################################################
##### RMAN flashback database to restore point
###################################################################################

echo RMAN flashback database to restore point
rman target / << _EOF_ >> $LOGFILE
run {

flashback database to restore point after_stop_apply;

}

exit

_EOF_

if [[ $? != 0 ]]; then

   echo "error  $?"

   default_error_msg

fi

 
###################################################################################
##### Oracle open reset logs
###################################################################################

 
echo Oracle SQL Apply
ORA_SID=$(echo $ORACLE_SID)
echo $ORA_SID
echo ------------------------------------------------------------------

 
$ORACLE_HOME/bin/sqlplus / as sysdba@IEMM << _EOF_ >> $LOGFILE
set pagesize 300
set linesize 300
WHENEVER SQLERROR EXIT SQL.SQLCODE
alter database open resetlogs;
ALTER DATABASE START LOGICAL STANDBY APPLY IMMEDIATE;
drop restore point after_stop_apply;
exit;
_EOF_

if [[ $? != 0 ]]; then

   echo "error  $?"

   default_error_msg

fi

##################################################################################
##################################################################################

$ORACLE_HOME/bin/sqlplus / as sysdba@IEMM << _EOF_ >> $DIAG
set pagesize 300
set linesize 300
select status from v\$instance;
select * from v\$dataguard_stats;
select GUARD_STATUS from v\$database;
exit;

_EOF_

###################################################################################
###################################################################################

FILE=$(cat $LOGFILE | grep -i error | wc -l )

echo $FILE

if [[ $FILE -gt 0 ]]; then

NACHRICHT="Go to $LOGFILE
contents of error log:

`cat $LOGFILE`

-----------------------------------------------------------------------------

"
BETREFF="IEMM Something goes wrong "
EMPFAENGER='arkadiusz.borucki@xxxx.com'
send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"

fi

echo $?
