#!/bin/bash
# -------------------------------------------------------------------------------
# Name:         warmup-cache.sh
# Description:  Web cache warm up process for the most relevant pages.
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      2.0b
# Date:         2016/10/28
# -------------------------------------------------------------------------------
# Usage:        warmup-cache.sh <ConfigProfileName> [-confirm] [-?|-h|--help]
# -------------------------------------------------------------------------------
# Dependencies: cat, ls, head, rm, wc, tr, touch, grep, awk, sed, date, curl
#               warmup-cache-<ConfigProfileName>.txt
# -------------------------------------------------------------------------------

BaseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
InstallDir=${BaseDir}/scripts
LogsDir=${BaseDir}/logs
TmpDir=${BaseDir}/tmp

CLI_Confirm="-confirm"

STATUS_OK=0
STATUS_ON=1
STATUS_OFF=0

ExitCode=0


# Default values for CLI parameters
ConfigurationProfile="$1"
Confirm=$STATUS_OFF
GetHelp=$STATUS_OFF


# Establish a SessionId and the StartTime
CurrentDate=$(date +%Y%m%d-%H%M%S)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"
StartTime="$(date '+%Y/%m/%d %H:%M:%S')"


# Load support functions and variables
. $InstallDir/libcore.sh


# Evaluate and Process CLI parameters
if [ -z $(echo "$1" | grep '^-') ] ; then
  if [ ! -f $InstallDir/"warmup-cache-$ConfigurationProfile.conf" ] ; then
    echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
    echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'):   warmup-cache.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"

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
  echo "  warmup-cache.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): WarmUp-Cache v2.0b                                                                       "
echo "WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

if [ -f "$TmpDir/.WarmUpCache-$ConfigurationProfile.lock" ] ; then
  echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring a lock ..."

  touch "$TmpDir/.WarmUpCache-$ConfigurationProfile.lock"
fi

echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation:     $(ConvertTo-String $Confirm) "
echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'):   Configuration Profile: $ConfigurationProfile "

if [ $Confirm -eq $STATUS_OFF ]; then
  read -p "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    if [ -f "$TmpDir/.WarmUpCache-$ConfigurationProfile.lock" ] ; then
      echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

      rm -f "$TmpDir/.WarmUpCache-$ConfigurationProfile.lock"
    else
      echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


for URL in $( cat $InstallDir/"warmup-cache-$ConfigurationProfile.txt" ); do
  echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): + Warming up URL: $URL"

  curl -s -k --user-agent "Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)" -X GET "$URL" > /dev/null

  if [ $? -eq 0 ]; then
    echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
  else
    echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi
done


if [ -f "$TmpDir/.WarmUpCache-$ConfigurationProfile.lock" ] ; then
  echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

  rm -f "$TmpDir/.WarmUpCache-$ConfigurationProfile.lock"
else
  echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi

echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[WarmUp-Cache] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode