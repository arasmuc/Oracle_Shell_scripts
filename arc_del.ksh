#!/usr/bin/bash
##############################################################################
#
#
#   This script delete arc logs older than 3 days
#   Arkadiusz Karol Borucki
#
#
#
#
##############################################################################

DATE=`date +%Y%m%d%H%M`
LOGFILE=/export/home/oracle/log/Delete_ARC_${DATE}.log
echo " "
echo " Filesystem size before arc delete " >> $LOGFILE
echo "-----------------------------------"
df -h /var/oracle/IEMM/archives/stdby_archives >> $LOGFILE
cd /var/oracle/IEMM/archives/stdby_archives
ls -ltr >> $LOGFILE

find /var/oracle/IEMM/archives/stdby_archives -mtime +3 -exec rm {} \; >> $LOGFILE

 if [[ $? != 0 ]]; then

   echo "Something went wrong" >> $LOGFILE
else

  echo " "

  echo "Arc logs older than 3 days deleted, current contents of the directory :" >> $LOGFILE

  echo "-----------------------------------------------------------------------"

     cd /var/oracle/IEMM/archives/stdby_archives

     ls -ltr >> $LOGFILE
df -h /var/oracle/IEMM/archives/stdby_archives >> $LOGFILE
fi
echo $?
