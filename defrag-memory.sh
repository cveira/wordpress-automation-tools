#!/bin/bash
# -------------------------------------------------------------------------------
# Name:         defrag-memory.sh
# Description:  Restarts web, application and/or database servers.
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      1.5b
# Date:         2016/10/27
# -------------------------------------------------------------------------------
# Usage:        defrag-memory.sh <proxy|web|runtime|db|all> [-confirm] [-?|-h|--help]
# -------------------------------------------------------------------------------
# Dependencies: cat, ls, head, rm, wc, tr, touch, grep, awk, sed, date, sleep, monit
#               Monit Group: web ([proxy +] web + appserver + dbserver)
#               Proper Monit Service Configuration: Groups, Dependencies and Operations
# -------------------------------------------------------------------------------

BaseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
InstallDir=${BaseDir}/scripts
LogsDir=${BaseDir}/logs
TmpDir=${BaseDir}/tmp

CLI_Confirm="-confirm"
CLI_ScopeProxyServer="proxy"
CLI_ScopeWebServer="web"
CLI_ScopeAppServer="runtime"
CLI_ScopeDbServer="db"
CLI_ScopeAllServices="all"

STATUS_OK=0
STATUS_ON=1
STATUS_OFF=0

TimeToWait="10s"
ExitCode=0


# Default values for CLI parameters
Scope="$1"
Confirm=$STATUS_OFF
GetHelp=$STATUS_OFF


# Initial state for configuration parameters
ProxyServerService="ProxyServerService"
WebServerService="WebServerService"
AppServerService="AppServerService"
DbServerService="DbServerService"


# Establish a SessionId and the StartTime
CurrentDate=$(date +%Y%m%d-%H%M%S)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"
StartTime="$(date '+%Y/%m/%d %H:%M:%S')"


# Load support functions and variables
. $InstallDir/libcore.sh


# Evaluate and Process CLI parameters
if [ -z $(echo "$1" | grep '^-') ] ; then
  if [ ! -f $InstallDir/"defrag-memory.conf" ] ; then
    echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find the configuration file"
    echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   defrag-memory.sh <proxy|web|runtime|db|all> [-confirm] [-?|-h|--help]"

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
  echo "  defrag-memory.sh <proxy|web|runtime|db|all> [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Defrag-Memory v1.5b                                                                       "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Loading configuration ..."

for ConfigurationItem in $( cat $InstallDir/defrag-memory.conf | grep -v "#" | grep . ); do
  PropertyName=`echo $ConfigurationItem  | awk -F "=" '{ print $1 }'`
  PropertyValue=`echo $ConfigurationItem | awk -F "=" '{ print $2 }'`

  if [ $PropertyName == $ProxyServerService ] ; then ProxyServerService="$PropertyValue" ; fi
  if [ $PropertyName == $WebServerService ]   ; then WebServerService="$PropertyValue"   ; fi
  if [ $PropertyName == $AppServerService ]   ; then AppServerService="$PropertyValue"   ; fi
  if [ $PropertyName == $DbServerService  ]   ; then DbServerService="$PropertyValue"    ; fi
done


if [ -f "$TmpDir/.DefragMemory.lock" ] ; then
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring a lock ..."

  touch "$TmpDir/.DefragMemory.lock"
fi


echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation:          $(ConvertTo-String $Confirm) "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   Target Scope:               $Scope "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   Proxy Server Service:       $ProxyServerService "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   Web Server Service:         $WebServerService "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   Application Server Service: $AppServerService "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   Database Server Service:    $DbServerService "
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

if [ $Confirm -eq $STATUS_OFF ]; then
  read -p "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    if [ -f "$TmpDir/.DefragMemory.lock" ] ; then
      echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

      rm -f "$TmpDir/.DefragMemory.lock"
    else
      echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): + Current service status:"

monit summary                         | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): + Supending service monitoring temporarily ..."

monit -g web unmonitor                | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): + Restarting services:"

case "$Scope" in
  "$ScopeProxyServer")
    monit restart $ProxyServerService | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"
  ;;

  "$ScopeWebServer")
    monit restart $WebServerService   | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"
  ;;


  "$ScopeAppServer")
    monit restart $AppServerService   | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"
  ;;

  "$ScopeDbServer")
    monit restart $DbServerService    | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"
  ;;

  "$ScopeAllServices")
    monit -g web restart              | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"
  ;;
esac

if [ $? -eq 0 ]; then
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


sleep $TimeToWait


echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): + Final state:"

monit summary                         | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): + Reenabling service monitoring"

monit -g web monitor                  | sed "s@^@[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


if [ -f "$TmpDir/.DefragMemory.lock" ] ; then
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

  rm -f "$TmpDir/.DefragMemory.lock"
else
  echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi

echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[Defrag-Memory] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode