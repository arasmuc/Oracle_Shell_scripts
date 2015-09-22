#!/usr/bin/ksh
###################################################################################
# Last commit information:
# $Revision:: 001             $
# $Author::  $
# $Date::    $
#
# Revision:: 002  2014-02-10 11:00   Ana-Maria Oancea   - modified $LOGFILE:
#                                                         OLD: LOGFILE=/export/home/oracle/log/`basename $0`_$MODE_${LEVEL}_${DATE}.log
#                                                         NEW: LOGFILE=/export/home/oracle/log/`basename $0`_${MODE}_${LEVEL}_${DATE}.log
#                                                       - added export NLS_DATE_FORMAT="DD-MM-YYYY HH24:MI:SS"
#
# Revision:: 003 2014-02-11 Ana-Maria Oancea - added self awareness - script does not start if it detects another instance of itself already running.
#                                            - added CROSSCHECK BACKUP before DELETE OBSOLETE for del_obsolete mode
#
# Revision:: 004 2014-02-18 Ana-Maria Oancea - removed 'AS COMPRESSED BACKUPSET' as per suggestions in SR #3-8566538621
#                                            - changed BETREFF and NACHRICHT to include $MODE
#
# Revision:: 005 2014-02-25 Fernando Borges Ferreira  - added extended error / signal handling (procedures trap_force_exit and default_error_msg)
#                                                     - extended self awareness, so that high priority backups (incremental lvl 0 and 1) can override lesser
#                                                       backups (procedure check_running_process)
#                                                     - ITIL conformity: a ticket is generated if the script aborts
#
# Revision:: 006 2014-03-06 Ana-Maria Oancea - changed RMAN Catalog connection string
#                                            - added variable SKRIPT_NAME_WITH_PATH=$0 so that the script behaves the same on Solaris 11 SPARC
# Revision:: 007 2014-09-23 Arkadiusz Karol Borucki - added two more imput parameters CATALOG and NOCATALOG
# Revision:: 008 2014-09-23 Arkadiusz Karol Borucki - added funcion sync_catalog to NOCATALOG mode
# Revision:: 009 2014-09-23 Arkadiusz Karol Borucki - added function check_catalog to to check if catalog is online
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

##
#
# Tries to exit cleanly if the process receives the following signals: TERM
#
##

 

        echo "$DATE: SIGTERM erhalten. Exit."  >> $LOGFILE

        EMPFAENGER='IT-OPS.Unix@db-is.com,IT-OPS.Database@db-is.com,ana-maria.oancea@db-is.com,arkadiusz.borucki@db-is.com,Shally.Batra@db-is.com'

        BETREFF="!!! WARNUNG !!! RMAN $MODE Sicherung von $ORACLE_SID wurde beendet"

        NACHRICHT="Die RMAN Sicherung $MODE $LEVEL fuer die Datenbank $ORACLE_SID wurde beendet, da ein Job mit hoeherer Prioritaet ausgefuehrt wird. Falls diese Nachricht mehrfach erzeugt wird, bitte die Logdatei $LOGFILE pruefen und die Sicherung ggf. neu starten!"

        send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "hoch" "$DEVMAIL"

        exit 1

        kill -9 $$

 

}

 
function default_error_msg

{
        EMPFAENGER='IT-OPS.Database@db-is.com'
        CC='IT-OPS.Unix@db-is.com,IT-OPS.Database@db-is.com,Arkadiusz.Borucki@db-is.com'
        echo "$DATE:  erhalten. Exit." >> $LOGFILE
        BETREFF="!!! ERROR !!! RMAN $MODE Sicherung von $ORACLE_SID wurde nicht korrekt beendet"
        NACHRICHT="Die RMAN Sicherung $MODE $LEVEL fuer die Datenbank $ORACLE_SID wurde nicht korrekt beendet! Bitte die Logdatei $LOGFILE pruefen und die Sicherung ggf. neu starten!"
        send_mail "$ABSENDER" "$EMPFAENGER" "$BETREFF" "$NACHRICHT" "hoch" "$CC"
        exit 1
}

 
function check_running_process

{
##
#
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

   BCC="fernando.borgesferreira@db-is.com; $7"

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

HEADER="From:noreply@db-is.com
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

 

ABSENDER='noreply@db-is.com'

EMPFAENGER='IT-OPS.Unix@db-is.com,IT-OPS.Database@db-is.com,arkadiusz.borucki@db-is.com,Shally.Batra@db-is.com'

DEVMAIL='arkadiusz.borucki@db-is.com,Shally.Batra@db-is.com'

 

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
