#!/bin/bash
# -------------------------------------------------------------------------------
# Name:         backup-site.sh
# Description:  Archives a backup copy of the files and database objects that
#               configure a web site.
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      1.5b
# Date:         2016/10/27
# -------------------------------------------------------------------------------
# Usage:        backup-site.sh <ConfigProfileName> [-confirm] [-?|-h|--help]
# -------------------------------------------------------------------------------
# Dependencies: cat, ls, head, rm, awk, wc, grep, tr, touch, grep, awk, sed, date,
#               tar, bzip2, mysqldump, mysqlcheck
#               backup-site-<ConfigProfileName>.conf
# -------------------------------------------------------------------------------

BaseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
InstallDir=${BaseDir}/scripts
LogsDir=${BaseDir}/logs
TmpDir=${BaseDir}/tmp

CLI_Confirm="-confirm"

STATUS_OK=0
STATUS_ON=1
STATUS_OFF=0

OriginalDir="$PWD"
ExitCode=0

# Default values for CLI parameters
ConfigurationProfile="$1"
Confirm=$STATUS_OFF
GetHelp=$STATUS_OFF


SiteSettings="backup-site-$ConfigurationProfile.conf"

# Initial state for configuration parameters
SiteFolder="SiteFolder"
BackupFolder="BackupFolder"
DbServer="DbServer"
DbName="DbName"
DbUser="DbUser"
DbPassword="DbPassword"


# Establish a SessionId and the StartTime
CurrentDate=$(date +%Y%m%d-%H%M%S)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"
StartTime="$(date '+%Y/%m/%d %H:%M:%S')"


# Load support functions and variables
. $InstallDir/libcore.sh


# Evaluate and Process CLI parameters
if [ -z $(echo "$1" | grep '^-') ] ; then
  if [ ! -f $InstallDir/"backup-site-$ConfigurationProfile.conf" ] ; then
    echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
    echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   backup-site.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"

    exit 1
  fi

  shift 1
else
  GetHelp=$STATUS_ON
fi

case "$(echo $1 | tr ":" "\n" | head -1)" in
  "-?"|"-h"|"--help") GetHelp=$STATUS_ON    ;;
  "$CLI_Confirm")     Confirm=$STATUS_ON    ;;
esac


# Display a quick help and exit
if [ $GetHelp -eq $STATUS_ON ] ; then
  echo
  echo "  backup-site.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Backup-Site v1.5b                                                                       "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Loading configuration ..."

for ConfigurationItem in $( cat "$InstallDir/backup-site-$ConfigurationProfile.conf" | grep -v "#" | grep . ); do
  PropertyName=`echo $ConfigurationItem  | awk -F "=" '{ print $1 }'`
  PropertyValue=`echo $ConfigurationItem | awk -F "=" '{ print $2 }'`

  if [ $PropertyName == $BackupFolder ] ; then BackupFolder="$PropertyValue" ; fi
  if [ $PropertyName == $SiteFolder   ] ; then SiteFolder="$PropertyValue"   ; fi
  if [ $PropertyName == $DbServer     ] ; then DbServer="$PropertyValue"     ; fi
  if [ $PropertyName == $DbName       ] ; then DbName="$PropertyValue"       ; fi
  if [ $PropertyName == $DbUser       ] ; then DbUser="$PropertyValue"       ; fi
  if [ $PropertyName == $DbPassword   ] ; then DbPassword="$PropertyValue"   ; fi
done


if [ -f "$TmpDir/.BackupSite-$ConfigurationProfile.lock" ] ; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring a lock ..."

  touch "$TmpDir/.BackupSite-$ConfigurationProfile.lock"
fi


CurrentWorkDir="$TmpDir/$CurrentSessionId"

echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation:  $(ConvertTo-String $Confirm) "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   Backup Folder:      $BackupFolder "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   Website Folder:     $SiteFolder "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   Database Server:    $DbServer "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   Database Name:      $DbName "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   Database User Name: $DbUser "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   Work Directory:     $CurrentWorkDir "
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

if [ $Confirm -eq $STATUS_OFF ]; then
  read -p "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    if [ -f "$TmpDir/.BackupSite-$ConfigurationProfile.lock" ] ; then
      echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

      rm -f "$TmpDir/.BackupSite-$ConfigurationProfile.lock"
    else
      echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Creating Working Directory: $CurrentWorkDir"

mkdir -p $CurrentWorkDir
cd $CurrentWorkDir

echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Dumping Dababase to file: DbBackup-$DbName-$CurrentSessionId.sql"

mysqldump -u $DbUser -p"$DbPassword" -h $DbServer --opt $DbName -r "DbBackup-$DbName-$CurrentSessionId.sql"

if [ $? -eq 0 ]; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Checking Database"

mysqlcheck -u $DbUser -p"$DbPassword" -h $DbServer $DbName --check | sed "s@^@[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   @g" | tee "DbCheck-$DbName-$CurrentSessionId.log"

if [ $? -eq 0 ]; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Auto-repairing Database"

mysqlcheck -u $DbUser -p"$DbPassword" -h $DbServer $DbName --auto-repair | sed "s@^@[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   @g" | tee "DbRepair-$DbName-$CurrentSessionId.log"

if [ $? -eq 0 ]; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Optimizing Database"

mysqlcheck -u $DbUser -p"$DbPassword" -h $DbServer $DbName --optimize | sed "s@^@[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   @g" | tee "DbOptimize-$DbName-$CurrentSessionId.log"

if [ $? -eq 0 ]; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Backing up web site files: FsBackup-$CurrentSessionId.tar.bz2"

tar -jcvf FsBackup-$CurrentSessionId.tar.bz2 $SiteFolder | sed "s@^@[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   @g" | tee "FsBackup-$CurrentSessionId.log"

if [ $? -eq 0 ]; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Creating backup archive: SiteBackup-$ConfigurationProfile-$CurrentSessionId.tar.bz2"

tar -jcvf SiteBackup-$ConfigurationProfile-$CurrentSessionId.tar.bz2 *.tar.bz2 *.sql *.log

if [ $? -eq 0 ]; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Copying backup file to: $BackupFolder"

cp -v SiteBackup-$ConfigurationProfile-$CurrentSessionId.tar.bz2 $BackupFolder/

if [ $? -eq 0 ]; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): + Cleaning work directory ..."

cd $OriginalDir
rm -rf $CurrentWorkDir > /dev/null


if [ -f "$TmpDir/.BackupSite-$ConfigurationProfile.lock" ] ; then
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

  rm -f "$TmpDir/.BackupSite-$ConfigurationProfile.lock"
else
  echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi

echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[Backup-Site] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode