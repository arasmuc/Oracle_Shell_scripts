#!/usr/bin/ksh
###################################################################################

###################################################################################
#set -x
USAGE="`basename $0`"
SKRIPT_NAME=`basename $0`
SKRIPT_NAME_WITH_PATH=$0
##
# Functions
# To do FBF: library laden
##

 function trap_force_exit
{
#
# Tries to exit cleanly if the process receives the following signals: TERM
#
##
        echo "$DATE: SIGTERM erhalten. Exit."  >> $LOGFILE
        EMPFAENGER='arkadiusz.borucki@xx-xx.xxx'
        BETREFF="!!! WARNUNG !!! RMAN $MODE Sicherung von $ORACLE_SID wurde beendet"
        NACHRICHT="Die RMAN Sicherung $MODE $LEVEL fuer die Datenbank $ORACLE_SID wurde beendet, da ein Job mit hoeherer Prioritaet ausgefuehrt wird. Falls diese Nachricht mehrfach erzeugt wird, bitte die Logdatei $LOGFILE pruefen und die Sicherung ggf. neu starten!"
        send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "hoch" "$DEVMAIL"

        exit 1

        kill -9 $$
}

function default_error_msg
{
        EMPFAENGER='IT-OPS.Database@xx-xx.xxx'
        CC='Arkadiusz.Borucki@xx-xx.xx'
        echo "$DATE:  erhalten. Exit." >> $LOGFILE
        BETREFF="!!! ERROR !!! RMAN $MODE Sicherung von $ORACLE_SID wurde nicht korrekt beendet"
        NACHRICHT="Die RMAN Sicherung $MODE $LEVEL fuer die Datenbank $ORACLE_SID wurde nicht korrekt beendet! Bitte die Logdatei $LOGFILE pruefen und die Sicherung ggf. neu starten!"
        send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "hoch" "$CC"
        exit 1
}

 
function check_running_process
{
# Start RMAN only if there is no other instance of rman_backup.ksh script already running:
#
###

   procCnt=$(ps -ef | grep "/usr/bin/ksh $SKRIPT_NAME_WITH_PATH" | grep -v grep | wc -l)
   if [[ "$procCnt" -lt 2 ]]; then
      #Mache weiter
      true
   else

      PID=`ps -eo pid,args | grep "/usr/bin/ksh $SKRIPT_NAME_WITH_PATH"|egrep -v "grep|$$" | awk '{ print $1 }'`
      SICHERUNGSART=`pargs -l $PID | perl -ne 'print "$1\n" if $_ =~ m/(archives|incremental 0|incremental 1)/g'`

       case $SICHERUNGSART in

             'incremental 0')

             # der aktive Prozess wird in Ruhe gelassen

               echo "$DATE:   ein Prozess mit hoeherer Prioritaet laeuft bereits. Exit." >> $LOGFILE
               BETREFF="!!! WARNUNG !!! RMAN $MODE Sicherung von $ORACLE_SID wird nicht ausgefuehrt"
               NACHRICHT="Die RMAN Sicherung $MODE $LEVEL fuer die Datenbank $ORACLE_SID wird nicht ausgefuehrt, da eine andere Instanz davon bereits aktiv ist. Die Sicherung $SICHERUNGSART ist vorrangig. Falls diese Meldung haeufig vorkommt, bitte die Logfiles pruefen und ggf. optimieren."
               send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"

               exit 0;

             ;;

             'incremental 1')

             # der aktive Prozess wird in Ruhe gelassen
              echo "$DATE:   ein Prozess mit hoeherer Prioritaet laeuft bereits. Exit." >> $LOGFILE
               BETREFF="!!! WARNUNG !!! RMAN $MODE Sicherung von $ORACLE_SID wird nicht ausgefuehrt"
               NACHRICHT="Die RMAN Sicherung $MODE $LEVEL fuer die Datenbank $ORACLE_SID wird nicht ausgefuehrt, da eine andere Instanz davon bereits aktiv ist. Die Sicherung $SICHERUNGSART ist vorrangig. Falls diese Meldung haeufig vorkommt, bitte die Logfiles pruefen und ggf. optimieren."
               send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"
               exit 0;
             ;;

             'archives')
             # Archivelog Sicherung wird gestoppt
               kill -s TERM $PID
             ;;

             * )
             # Mache weiter
               true
      esac

 
   fi

}

function send_mail
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

   BCC="arkadiusz.borucki@xx-xx.xxx; $7"

fi

 

FUSSZEILE="------------------------------------------

Dieses Ticket soll IT-OPS Database/IT-OPS UNIX zugewiesen werden!
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

 

# set profile

. $HOME/.profile

 

 sync_catalog ()

{

cat_alive=$(tnsping PRMANCAT | grep OK | grep -v grep | wc -l)

if [[ "cat_alive" -eq 1 ]]; then

 

rman target / "$CATA" <<_EOF_>> $LOGFILE

run{

resync catalog

;}

    exit

_EOF_

else

echo "$DATE:   RMAN-Katalog RMANCAT ist nicht verfügbar" >> $LOGFILE

               BETREFF="WARNUNG ! RMAN-Katalog RMANCAT ist nicht verfügbar - HOST=sdb161f1 PORT=1521 vom `hostname`"
               NACHRICHT=" RMAN-Katalog RMANCAT ist nicht verfügbar - HOST=sdb161f1 PORT=1521 vom `hostname`"
               send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"

 
echo  RMAN-Katalog RMANCAT ist nicht verfügbar
fi
}

check_catalog ()
{

cat_alive=$(tnsping PRMANCAT | grep OK | grep -v grep | wc -l)

if [[ "cat_alive" -ne 1 ]]; then

echo "$DATE:   RMAN-Katalog RMANCAT ist nicht verfügbar" >> $LOGFILE
               BETREFF="WARNUNG ! RMAN-Katalog RMANCAT ist nicht verfügbar - HOST=sdb161f1 PORT=1521 vom `hostname`"
               NACHRICHT=" RMAN-Katalog RMANCAT ist nicht verfügbar - HOST=sdb161f1 PORT=1521 vom `hostname`"
               send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "$DEVMAIL"

echo RMAN-Katalog RMANCAT ist nicht verfügbar

exit 1

else

 echo RMAN-Katalog RMANCAT ist verfügbar
fi

}
###
#  Oracle RMAN variables
###

CATA="catalog rmancat/rmancat@PRMANCAT"

 for parameter in $*

do
       if [[  -n `echo $parameter | grep -w [0-9]` ]]; then
                LEVEL=$parameter
        elif [[ $parameter = 'cumulative' || $parameter = 'incremental' || $parameter = 'archives' || $parameter = 'controlfile' || $parameter = 'del_obsolete' || $parameter = 'del_archives' ]]; then
                MODE=$parameter
        fi
done

 

####################################

#lev_imput=$(echo $LEVEL)
#if [[ "lev_imput" -gt 1 ]]; then
#echo ----------------------------------------------------------
#echo
#echo WARNING - Syntax error - just 0 or 1 allowed
#echo
#echo ----------------------------------------------------------
#exit 1
#fi
####################################

for last; do true; done
TYPE=$last

####################################

SID=$*
SID=$(echo $SID | awk -F" " '{print $(NF-1)}')
ORACLE_SID=$SID
export ORACLE_SID

###############################################

# Check syntax
cat_input=$(echo $TYPE | grep -i -w  catalog | wc -l)
nocat_input=$(echo $TYPE | grep -i -w  nocatalog | wc -l)

if [[ "cat_input" -ne 1 && "nocat_input" -ne 1 ]]; then

 
echo ----------------------------------------------------------
echo
echo WARNING - Syntax error CATALOG or NOCATALOG option ommited
echo
echo ----------------------------------------------------------

exit 1

fi
##
# Logfile
##

DATE=`date +%Y%m%d%H%M`
LOGFILE=/export/home/oracle/log/`basename $0`_${SID}_${MODE}_${LEVEL}_${TYPE}_${DATE}.log

echo "Following parameters has been set :"
echo -------------------------------------------------

echo "SID     $SID"
echo "MODE    $MODE"
echo "LEVEL   $LEVEL"
echo "TYPE    $TYPE"

echo --------------------------------------------------

#
# Einstellung fuer Emailversand
#
###

 

ABSENDER='noreply@xx-xx.xxx'
EMPFAENGER='arkadiusz.borucki@xx-xx.xxx'
DEVMAIL='arkadiusz.borucki@x-xx.xxx'

trap trap_force_exit TERM
trap default_error_msg INT

case $LEVEL in

      0)

         check_running_process
         RMAN_COMM="BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL $LEVEL DATABASE FILESPERSET 1;"

      ;;

      1)

         check_running_process
         RMAN_COMM="BACKUP AS COMPRESSED BACKUPSET $MODE LEVEL $LEVEL DATABASE FILESPERSET 1;"

      ;;

esac

 

case $MODE in

      archives)

         check_running_process

         RMAN_COMM="CROSSCHECK ARCHIVELOG ALL;
         BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES FILESPERSET 10;
         DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2/2.4' backed up 1 times to device type disk;"
      ;;

      controlfile)

         RMAN_COMM="BACKUP CURRENT CONTROLFILE;"

      ;;

      del_obsolete)

         RMAN_COMM="CROSSCHECK BACKUP;
         DELETE NOPROMPT EXPIRED BACKUP;
         CROSSCHECK ARCHIVELOG ALL;
         DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
         DELETE NOPROMPT OBSOLETE;"
      ;;

      del_archives)

         RMAN_COMM="DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';"

      ;;

esac

 

case $TYPE in

    'catalog'|'CATALOG')
echo $RMAN_COMM

#check_catalog

   #rman target / "$CATA" <<_EOF_>> $LOGFILE

    rman target / <<_EOF_>> $LOGFILE
      set backup files for device type DISK to accessible;
       run{

            CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/var/oracle/$SID/rman/backupset/$SID-%d_%s_%p_%T.bak';
           $RMAN_COMM

          }
    exit
_EOF_

if [[ $? != 0 ]]; then

  default_error_msg
  cat $LOGFILE

else

echo
echo "Finished - no errors has been found"
echo

fi

check_catalog
sync_catalog
;;

 
  'nocatalog'|'NOCATALOG')

echo $RMAN_COMM
rman target / <<_EOF_>> $LOGFILE

      set backup files for device type DISK to accessible;

       run{

            CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/var/oracle/$SID/rman/backupset/$SID-%d_%s_%p_%T.bak';
           $RMAN_COMM

          }

    exit

_EOF_

#sync_catalog

 

if [[ $? != 0 ]]; then

  default_error_msg
  cat $LOGFILE

else

echo
echo "Finished - no erros has been found"
echo

fi
;;

esac

if [[ $? != 0 ]]; then

    default_error_msg
fi
# Verifiziert die Anzahl Parameter
#

if [[ $# -lt 2 ]]; then

        echo $USAGE
        exit 1
fi
