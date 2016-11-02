#!/bin/bash
# -------------------------------------------------------------------------------
# Name:        backup-offsite.sh
# Description: Copies the last backup to another machine via SCP (SSH)
# Author:      Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:     1.5b
# Date:        2016/09/30
# -------------------------------------------------------------------------------
# Usage:        backup-offsite.sh <ConfigProfileName> [-confirm] [-?|-h|--help]
# -------------------------------------------------------------------------------
# Dependencies: cat, ls, head, rm, wc, tr, touch, grep, awk, sed, date, scp
#               backup-offsite-<ConfigProfileName>.conf
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


# Initial state for configuration parameters
RemoteNode="RemoteNode"
RemoteUserName="RemoteUserName"
LocalDir="LocalDir"
RemoteDir="RemoteDir"
SSHIdentityFile="SSHIdentityFile"
FilesToTransfer="FilesToTransfer"


# Establish a SessionId and the StartTime
CurrentDate=$(date +%Y%m%d-%H%M%S)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"
StartTime="$(date '+%Y/%m/%d %H:%M:%S')"


# Load support functions and variables
. $InstallDir/libcore.sh


# Evaluate and Process CLI parameters
if [ -z $(echo "$1" | grep '^-') ] ; then
  if [ ! -f $InstallDir/"backup-offsite-$ConfigurationProfile.conf" ] ; then
    echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
    echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   backup-offsite.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"

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
  echo "  backup-offsite.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Backup-Offsite v1.5b                                                                       "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Loading configuration ..."

for ConfigurationItem in $( cat "$InstallDir/backup-offsite-$ConfigurationProfile.conf" | grep -v "#" | grep . ); do
  PropertyName=`echo $ConfigurationItem  | awk -F ":" '{ print $1 }'`
  PropertyValue=`echo $ConfigurationItem | awk -F ":" '{ print $2 }'`

  if [ $PropertyName == $RemoteNode      ] ; then RemoteNode="$PropertyValue"      ; fi
  if [ $PropertyName == $RemoteUserName  ] ; then RemoteUserName="$PropertyValue"  ; fi
  if [ $PropertyName == $LocalDir        ] ; then LocalDir="$PropertyValue"        ; fi
  if [ $PropertyName == $RemoteDir       ] ; then RemoteDir="$PropertyValue"       ; fi
  if [ $PropertyName == $SSHIdentityFile ] ; then SSHIdentityFile="$PropertyValue" ; fi
  if [ $PropertyName == $FilesToTransfer ] ; then FilesToTransfer="$PropertyValue" ; fi
done


if [ -f "$TmpDir/.BackupOffsite-$ConfigurationProfile.lock" ] ; then
  echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring a lock ..."

  touch "$TmpDir/.BackupOffsite-$ConfigurationProfile.lock"
fi


echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation: $(ConvertTo-String $Confirm) "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   Remote Node:       $RemoteNode "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   Remote User Name:  $RemoteUserName "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   Local directory:   $LocalDir "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   Remote directory:  $RemoteDir "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   SSH Identity File: $SSHIdentityFile "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   Files to transfer: $FilesToTransfer "
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

if [ $Confirm -eq $STATUS_OFF ]; then
  read -p "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    if [ -f "$TmpDir/.BackupOffsite-$ConfigurationProfile.lock" ] ; then
      echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

      rm -f "$TmpDir/.BackupOffsite-$ConfigurationProfile.lock"
    else
      echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


cd "$LocalDir"

for File in $( ls -1td * | head -$FilesToTransfer ); do
  echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): + Transferring file: $File"

  # SSH Session options: Protocol Version 2 + Preserve Time stamp + Compression + Batch mode
  scp -2pBCv -i ${SSHIdentityFile} ${File} ${RemoteUserName}@${RemoteNode}:${RemoteDir} 2>&1 | sed "s@^@[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

  if [ $? -eq 0 ]; then
    echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
  else
    echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi
done

cd "$OriginalDir"


if [ -f "$TmpDir/.BackupOffsite-$ConfigurationProfile.lock" ] ; then
  echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

  rm -f "$TmpDir/.BackupOffsite-$ConfigurationProfile.lock"
else
  echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi

echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[Backup-Offsite] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode