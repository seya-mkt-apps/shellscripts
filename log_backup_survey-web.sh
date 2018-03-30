#!/bin/bash
FROMPATH=/var/log/httpd
TOPATH=/mnt/backup_store/apache/forSurvey
HOSTLIST=/home/deploy/survey-web_hostlist.txt
FILENAMEPATTERN="*access_log.gz *error_log.gz"
FILENUM=7
USER=deploy
GROUP=deploy

TARGETFILELIST_LASTYM=/tmp/mv_filelist_lastym_survey-web.txt
TARGETFILELIST_THISYM=/tmp/mv_filelist_thisym_survey-web.txt

BASEDAY=`date +'%Y%m01'`
LASTYM=`date -d "$BASEDAY -1 month" +'%Y%m'`
THISYM=`date '+%Y%m'`

FILENUM=$(( FILENUM + 1 ))

MVCOMMAND="rsync -av --bwlimit=10240 --remove-source-files"

echo "Check last month "$LASTYM" directory."
if [ ! -d $TOPATH/$LASTYM ]; then
  sudo mkdir -p $TOPATH/$LASTYM
  sudo chown $USER:$GROUP $TOPATH/$LASTYM
fi

echo "Check this month "$THISYM" directory."
if [ ! -d $TOPATH/$THISYM ]; then
  sudo mkdir -p $TOPATH/$THISYM
  sudo chown $USER:$GROUP $TOPATH/$THISYM
fi

for TARGETFILE in $FILENAMEPATTERN; do
  for FROMHOST in `cat $HOSTLIST`; do
    HOSTIP=(`echo $FROMHOST | tr -s ',' ' '`)
    PERM=`ssh -t -t $USER@${HOSTIP[0]} stat -c "%a" $FROMPATH`
    PERM=`echo $PERM | tr -d '\r'`
    echo "Change permission target file directory"
    ssh -t -t $USER@${HOSTIP[0]} "sudo -p '' sh -c 'chmod 777 $FROMPATH'"

    echo "Getting filelist last month."
    ssh $USER@${HOSTIP[0]} ls -t $FROMPATH/$TARGETFILE | grep $LASTYM | awk -F "/" '{print $NF}' > $TARGETFILELIST_LASTYM

    echo "Getting filelist this month."
    ssh $USER@${HOSTIP[0]} ls -t $FROMPATH/$TARGETFILE | tail -n+$FILENUM | grep $THISYM | awk -F "/" '{print $NF}' > $TARGETFILELIST_THISYM

    echo "Change permisson logfiles."
    ssh -t -t $USER@${HOSTIP[0]} "sudo -p '' sh -c 'chown $USER:$GROUP $FROMPATH/$TARGETFILE'"

    echo "Moving last month logfiles."
    sudo -u $USER $MVCOMMAND --files-from=$TARGETFILELIST_LASTYM ${HOSTIP[0]}:$FROMPATH $TOPATH/$LASTYM
    for FILENAME in `cat $TARGETFILELIST_LASTYM`; do
      cd $TOPATH/$LASTYM
      mv $FILENAME ${HOSTIP[1]}_$FILENAME
    done

    echo "Moving this month logfiles."
    sudo -u $USER $MVCOMMAND --files-from=$TARGETFILELIST_THISYM ${HOSTIP[0]}:$FROMPATH $TOPATH/$THISYM
    for FILENAME in `cat $TARGETFILELIST_THISYM`; do
      cd $TOPATH/$THISYM
      mv $FILENAME ${HOSTIP[1]}_$FILENAME
    done
    
    echo "Restore permission logfiles directory."
    ssh -t -t $USER@${HOSTIP[0]} "sudo -p '' sh -c 'chmod $PERM $FROMPATH'"
    echo "---"${HOSTIP[1]}" logfiles move end---"
  done
done
exit 0
