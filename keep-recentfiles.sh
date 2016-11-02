#!/bin/bash
# -------------------------------------------------------------------------------
# Name:         keep-recentfiles.sh
# Description:  Clean a folder from old files 
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      3.1b
# Date:         2016/10/17
# -------------------------------------------------------------------------------
# Usage:        keep-recentfiles.sh <ConfigProfileName> [-DryRun] [-force] [-confirm] [-?|-h|--help]
# -------------------------------------------------------------------------------
# Dependencies: cat, ls, head, rm, wc, tr, touch, grep, awk, sed, date
#               keep-recentfiles-<ConfigProfileName>.conf
# -------------------------------------------------------------------------------

BaseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
InstallDir=${BaseDir}/scripts
LogsDir=${BaseDir}/logs
TmpDir=${BaseDir}/tmp

CLI_DryRun="-DryRun"
CLI_Force="-force"
CLI_Confirm="-confirm"

STATUS_OK=0
STATUS_ON=1
STATUS_OFF=0

OriginalDir="$PWD"
FilesToDelete=0
ExitCode=0

# Default values for CLI parameters
ConfigurationProfile="$1"
DryRun=$STATUS_OFF
Force=$STATUS_OFF
Confirm=$STATUS_OFF
GetHelp=$STATUS_OFF


# Initial state for configuration parameters
TargetPath="TargetPath"
FileGroups="FileGroups"
FileGroupInstancesToDelete="FileGroupInstancesToDelete"
FilesPerGroup="FilesPerGroup"
MinimumFileGroupInstances="MinimumFileGroupInstances"


# Establish a SessionId and the StartTime
CurrentDate=$(date +%Y%m%d-%H%M%S)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"
StartTime="$(date '+%Y/%m/%d %H:%M:%S')"


# Load support functions and variables
. $InstallDir/libcore.sh


# Evaluate and Process CLI parameters
if [ -z $(echo "$1" | grep '^-') ] ; then
  if [ ! -f $InstallDir/"keep-recentfiles-$ConfigurationProfile.conf" ] ; then
    echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
    echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   keep-recentfiles.sh <ConfigProfileName> [-DryRun] [-force] [-confirm] [-?|-h|--help]"

    exit 1
  fi

  shift 1
else
  GetHelp=$STATUS_ON
fi

case "$(echo $1 | tr ":" "\n" | head -1)" in
  "-?"|"-h"|"--help") GetHelp=$STATUS_ON    ;;
  "$CLI_DryRun")      DryRun=$STATUS_ON     ;;
  "$CLI_Force")       Force=$STATUS_ON      ;;
  "$CLI_Confirm")     Confirm=$STATUS_ON    ;;
esac

case "$(echo $2 | tr ":" "\n" | head -1)" in
  "$CLI_DryRun")      DryRun=$STATUS_ON     ;;
  "$CLI_Force")       Force=$STATUS_ON      ;;
  "$CLI_Confirm")     Confirm=$STATUS_ON    ;;
esac

case "$(echo $3 | tr ":" "\n" | head -1)" in
  "$CLI_DryRun")      DryRun=$STATUS_ON     ;;
  "$CLI_Force")       Force=$STATUS_ON      ;;
  "$CLI_Confirm")     Confirm=$STATUS_ON    ;;
esac


# Display a quick help and exit
if [ $GetHelp -eq $STATUS_ON ] ; then
  echo
  echo "  keep-recentfiles.sh <ConfigProfileName> [-DryRun] [-force] [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Keep-RecentFiles v3.1b                                                                     "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Loading configuration ..."

IFS=$'\n'
for ConfigurationItem in $( cat $InstallDir/"keep-recentfiles-$ConfigurationProfile.conf" | grep -v "#" | grep . ); do
  PropertyName=`echo $ConfigurationItem  | awk -F "=" '{ print $1 }'`
  PropertyValue=`echo $ConfigurationItem | awk -F "=" '{ print $2 }'`

  if [ $PropertyName == $TargetPath                 ] ; then TargetPath="$PropertyValue"                 ; fi
  if [ $PropertyName == $FileGroups                 ] ; then FileGroups="$PropertyValue"                 ; fi
  if [ $PropertyName == $FileGroupInstancesToDelete ] ; then FileGroupInstancesToDelete="$PropertyValue" ; fi
  if [ $PropertyName == $FilesPerGroup              ] ; then FilesPerGroup="$PropertyValue"              ; fi
  if [ $PropertyName == $MinimumFileGroupInstances  ] ; then MinimumFileGroupInstances="$PropertyValue"  ; fi
done
unset IFS


if [ -f "$TmpDir/.KeepRecentFiles-$ConfigurationProfile.lock" ] ; then
  echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring a lock ..."

  touch "$TmpDir/.KeepRecentFiles-$ConfigurationProfile.lock"
fi


FilesToDelete=$(($FileGroupInstancesToDelete*$FileGroups*$FilesPerGroup))
FilesToKeep=$(($MinimumFileGroupInstances*$FileGroups*$FilesPerGroup))

echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Configuration Profile:          $ConfigurationProfile "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Dry run:                        $(ConvertTo-String $DryRun) "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Force Clean Up:                 $(ConvertTo-String $Force) "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation:              $(ConvertTo-String $Confirm) "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Target directory:               $TargetPath "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   File Groups:                    $FileGroups "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   File Group Instances To Delete: $FileGroupInstancesToDelete "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Minimum File Group Instances:   $MinimumFileGroupInstances "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Files Per Group:                $FilesPerGroup "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Files To Delete:                $FilesToDelete "
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   Minimum Files To Keep:          $FilesToKeep "

if [ $Confirm -eq $STATUS_OFF ]; then
  read -p "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    if [ -f "$TmpDir/.KeepRecentFiles-$ConfigurationProfile.lock" ] ; then
      echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

      rm -f "$TmpDir/.KeepRecentFiles-$ConfigurationProfile.lock"
    else
      echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


cd "$TargetPath"

if [ $( ls -1tr | wc -l ) -gt $FilesToKeep ] || [ $Force -eq $STATUS_ON ]; then
  if [ $( ls -1tr | wc -l ) -gt $FilesToKeep ]; then
    echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): The minimum number of files has been reached."
  fi

  echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): + Removing older files ..."

  for File in $( ls -1tr | head -n $FilesToDelete ); do
    echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   File: $File"

    if [ $DryRun -eq $STATUS_OFF ]; then
      rm -f $File

      if [ $? -eq 0 ]; then
        echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
      else
        echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
        ExitCode=$(($ExitCode+1))
      fi
    fi
  done
else
  echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): The minimum number of files has not been reached. Nothing has been deleted."
fi

cd "$OriginalDir"


if [ -f "$TmpDir/.KeepRecentFiles-$ConfigurationProfile.lock" ] ; then
  echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

  rm -f "$TmpDir/.KeepRecentFiles-$ConfigurationProfile.lock"
else
  echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi


echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[Keep-RecentFiles] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode