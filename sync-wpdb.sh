#!/bin/bash
# -------------------------------------------------------------------------------
# Name:         sync-wpdb.sh
# Description:  Synchronizes WordPress MySQL tables between two databases using a
#               Percona Toolkit CLI tool called pt-table-sync and wp-cli.
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      1.2b
# Date:         2016/09/30
# License:      GPL 2.0
# -------------------------------------------------------------------------------
# Usage:        sync-wpdb.sh [ConfigurationProfile] [-DBSyncOnly|-DBFixOnly] [-confirm] [-?|-h|--help]
# -------------------------------------------------------------------------------
# Dependencies: cat, ls, head, rm, wc, tr, touch, grep, awk, sed, date, ssh
#               pt-table-sync, wp, wp-cli.yml, mysqlcheck, libcore.sh
# -------------------------------------------------------------------------------
# Remarks:
#   + Make sure to configure wp-cli.yml files for your Configuration Profiles.
#   + Media files and other changes are not processed by this script. Use lsyncd
#     or some other alternatives to replicate files.
#   + If you plan to run concurrent instances of sync-wpdb.sh with different
#     Configuration Profiles, each one of them pretending to open SSH Tunnels,
#     Make sure that they have different values for DestinationDbServerPort.
# -------------------------------------------------------------------------------

BaseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
InstallDir=${BaseDir}/scripts
LogsDir=${BaseDir}/logs
TmpDir=${BaseDir}/tmp

CLI_DBSyncOnly="-DBSyncOnly"
CLI_DBFixOnly="-DBFixOnly"
CLI_Confirm="-confirm"

STATUS_OK=0
STATUS_ON=1
STATUS_OFF=0

STATUS_PTTABLESYNC_SUCCESS=0
STATUS_PTTABLESYNC_ERROR=1
STATUS_PTTABLESYNC_SYNCED=2
STATUS_PTTABLESYNC_SYNCEDWITHERRORS=3

WPCLI_CURRENT_SETTINGS="$WP_CLI_CONFIG_PATH"

ExitCode=0

# Default values for CLI parameters
ConfigurationProfile="$1"
DBSyncOnly=$STATUS_OFF
DBFixOnly=$STATUS_OFF
Confirm=$STATUS_OFF
GetHelp=$STATUS_OFF


# Initial state for configuration parameters
SSHTunnelEnabled="SSHTunnelEnabled"
SSHTunnelUserName="SSHTunnelUserName"
SSHTunnelKeyFile="SSHTunnelKeyFile"
SSHTunnelTimeOut="SSHTunnelTimeOut"
SSHTunnelEndPoint="SSHTunnelEndPoint"
SSHTunnelRemotePort="SSHTunnelRemotePort"

SourceDbServer="SourceDbServer"
SourceDbServerPort="SourceDbServerPort"
SourceDbUserName="SourceDbUserName"
SourceDbPassword="SourceDbPassword"
SourceDbName="SourceDbName"

DestinationDbServer="DestinationDbServer"
DestinationDbServerPort="DestinationDbServerPort"
DestinationDbUserName="DestinationDbUserName"
DestinationDbPassword="DestinationDbPassword"
DestinationDbName="DestinationDbName"

TablesToSync="TablesToSync"
SourceDomain="SourceDomain"
DestinationDomain="DestinationDomain"
SourcePath="SourcePath"
DestinationPath="DestinationPath"
PostContentFilter="PostContentFilter"
PostMetaContentFilter="PostMetaContentFilter"
WPCLISessionSettings="WPCLISessionSettings"
WPTablePrefix="WPTablePrefix"


# Establish a SessionId and the StartTime
CurrentDate=$(date +%Y%m%d-%H%M%S)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"
StartTime="$(date '+%Y/%m/%d %H:%M:%S')"


# Load support functions and variables
. $InstallDir/libcore.sh


# Evaluate and Process CLI parameters
if [ -z $(echo "$1" | grep '^-') ] ; then
  if [ ! -f $InstallDir/"sync-wpdb-$ConfigurationProfile.conf" ] ; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   sync-wpdb.sh <ConfigProfileName> [-DBSyncOnly|-DBFixOnly] [-confirm] [-?|-h|--help]"

    exit 1
  fi

  shift 1
else
  GetHelp=$STATUS_ON
fi

case "$(echo $1 | tr ":" "\n" | head -1)" in
  "-?"|"-h"|"--help") GetHelp=$STATUS_ON    ;;
  "$CLI_DBSyncOnly")  DBSyncOnly=$STATUS_ON ;;
  "$CLI_DBFixOnly")   DBFixOnly=$STATUS_ON  ;;
  "$CLI_Confirm")     Confirm=$STATUS_ON    ;;
esac

case "$(echo $2 | tr ":" "\n" | head -1)" in
  "$CLI_Confirm")     Confirm=$STATUS_ON    ;;
esac


# Display a quick help and exit
if [ $GetHelp -eq $STATUS_ON ] ; then
  echo
  echo "  sync-wpdb.sh <ConfigProfileName> [-DBSyncOnly|-DBFixOnly] [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Sync-WpDB v1.2b                                                                            "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Loading configuration ..."

IFS=$'\n'
for ConfigurationItem in $( cat $InstallDir/"sync-wpdb-$ConfigurationProfile.conf" | grep -v "#" | grep . ); do
  PropertyName=`echo $ConfigurationItem    | awk -F "=" '{ print $1 }'`
  PropertyValue=`echo "$ConfigurationItem" | awk -F "=" '{ print $2 }'`

  if [ $PropertyName == $SSHTunnelEnabled        ] ; then SSHTunnelEnabled="$PropertyValue"        ; fi
  if [ $PropertyName == $SSHTunnelUserName       ] ; then SSHTunnelUserName="$PropertyValue"       ; fi
  if [ $PropertyName == $SSHTunnelKeyFile        ] ; then SSHTunnelKeyFile="$PropertyValue"        ; fi
  if [ $PropertyName == $SSHTunnelTimeOut        ] ; then SSHTunnelTimeOut="$PropertyValue"        ; fi
  if [ $PropertyName == $SSHTunnelEndPoint       ] ; then SSHTunnelEndPoint="$PropertyValue"       ; fi
  if [ $PropertyName == $SSHTunnelRemotePort     ] ; then SSHTunnelRemotePort="$PropertyValue"     ; fi

  if [ $PropertyName == $SourceDbServer          ] ; then SourceDbServer="$PropertyValue"          ; fi
  if [ $PropertyName == $SourceDbServerPort      ] ; then SourceDbServerPort="$PropertyValue"      ; fi
  if [ $PropertyName == $SourceDbUserName        ] ; then SourceDbUserName="$PropertyValue"        ; fi
  if [ $PropertyName == $SourceDbPassword        ] ; then SourceDbPassword="$PropertyValue"        ; fi
  if [ $PropertyName == $SourceDbName            ] ; then SourceDbName="$PropertyValue"            ; fi

  if [ $PropertyName == $DestinationDbServer     ] ; then DestinationDbServer="$PropertyValue"     ; fi
  if [ $PropertyName == $DestinationDbServerPort ] ; then DestinationDbServerPort="$PropertyValue" ; fi
  if [ $PropertyName == $DestinationDbUserName   ] ; then DestinationDbUserName="$PropertyValue"   ; fi
  if [ $PropertyName == $DestinationDbPassword   ] ; then DestinationDbPassword="$PropertyValue"   ; fi
  if [ $PropertyName == $DestinationDbName       ] ; then DestinationDbName="$PropertyValue"       ; fi

  if [ $PropertyName == $TablesToSync            ] ; then TablesToSync="$PropertyValue"            ; fi
  if [ $PropertyName == $SourceDomain            ] ; then SourceDomain="$PropertyValue"            ; fi
  if [ $PropertyName == $DestinationDomain       ] ; then DestinationDomain="$PropertyValue"       ; fi
  if [ $PropertyName == $SourcePath              ] ; then SourcePath="$PropertyValue"              ; fi
  if [ $PropertyName == $DestinationPath         ] ; then DestinationPath="$PropertyValue"         ; fi
  if [ $PropertyName == $PostContentFilter       ] ; then PostContentFilter="$PropertyValue"       ; fi
  if [ $PropertyName == $PostMetaContentFilter   ] ; then PostMetaContentFilter="$PropertyValue"   ; fi

  if [ $PropertyName == $WPCLISessionSettings    ] ; then WPCLISessionSettings="$PropertyValue"    ; fi
  if [ $PropertyName == $WPTablePrefix           ] ; then WPTablePrefix="$PropertyValue"           ; fi
done
unset IFS


if [ ! -f ${InstallDir}/${WPCLISessionSettings} ] ; then
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile for WP-CLI named ${WPCLISessionSettings}"

  exit 1
else
  export WP_CLI_CONFIG_PATH=${InstallDir}/${WPCLISessionSettings}
fi

if [ -f "$TmpDir/.SyncWpDB-$ConfigurationProfile.lock" ] ; then
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring a lock ..."

  touch "$TmpDir/.SyncWpDB-$ConfigurationProfile.lock"
fi

echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Configuration Profile:      $ConfigurationProfile "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   DBSyncOnly:                 $(ConvertTo-String $DBSyncOnly) "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   DBFixOnly:                  $(ConvertTo-String $DBFixOnly) "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation:          $(ConvertTo-String $Confirm) "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   SSH Tunnel:                 $(ConvertTo-String $SSHTunnelEnabled) "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   SSH Tunnel User Name:       $SSHTunnelUserName "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   SSH Tunnel Key file:        $SSHTunnelKeyFile "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   SSH Tunnel Time Out:        $SSHTunnelTimeOut "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   SSH Tunnel Endpoint:        $SSHTunnelEndPoint "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   SSH Tunnel Remote Port:     $SSHTunnelRemotePort "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Source DB Server:           $SourceDbServer "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Source DB Server Port:      $SourceDbServerPort "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Source DB:                  $SourceDbName "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Source DB User Name:        $SourceDbUserName "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Destination DB Server:      $DestinationDbServer "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Destination DB Server Port: $DestinationDbServerPort "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Destination DB:             $DestinationDbName "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Destination DB User Name:   $SourceDbUserName "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Tables yo Sync:             $TablesToSync "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Source Domain:              $SourceDomain "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Destination Domain:         $DestinationDomain "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Source Path:                $SourcePath "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Destination Path:           $DestinationPath "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Posts Content Filter:       $PostContentFilter "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   Posts Meta Content Filter:  $PostMetaContentFilter "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   WP-CLI Session Settings:    $WPCLISessionSettings "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   WP Table Prefix:            $WPTablePrefix "
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

if [ "$Confirm" == "$STATUS_OFF" ]; then
  read -p "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Restoring original WP-CLI Settings ..."
    export WP_CLI_CONFIG_PATH="$WPCLI_CURRENT_SETTINGS"

    if [ -f "$TmpDir/.SyncWpDB-$ConfigurationProfile.lock" ] ; then
      echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

      rm -f "$TmpDir/.SyncWpDB-$ConfigurationProfile.lock"
    else
      echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


if [ "$DBFixOnly" == "$STATUS_OFF" ]; then
  if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): + Opening SSH Tunnel ..."

    ssh -i ${SSHTunnelKeyFile} \
        -f -o ExitOnForwardFailure=yes \
        -L ${DestinationDbServerPort}:${DestinationDbServer}:${SSHTunnelRemotePort} \
        ${SSHTunnelUserName}@${SSHTunnelEndPoint} \
        sleep ${SSHTunnelTimeOut}
  fi

  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): + Synchronizing tables ..."

  for Table in $( echo $TablesToSync | tr "," "\n" | grep -v "^$" ); do
    pt-table-sync --verbose \
                  --execute h=${SourceDbServer},P=${SourceDbServerPort},u=${SourceDbUserName},p="${SourceDbPassword}",D=${SourceDbName},t=${Table} \
                            h=${DestinationDbServer},P=${DestinationDbServerPort},u=${DestinationDbUserName},p="${DestinationDbPassword}",D=${DestinationDbName} 2>&1 | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

    if [ $? -eq 0 ]; then
      echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
    else
      echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
      ExitCode=$(($ExitCode+1))
    fi
  done

  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): + Synchronizing tables subject to content routing rules and filters ..."

  pt-table-sync --verbose \
                --where "${PostMetaContentFilter}" \
                --execute h=${SourceDbServer},P=${SourceDbServerPort},u=${SourceDbUserName},p="${SourceDbPassword}",D=${SourceDbName},t=${WPTablePrefix}postmeta \
                          h=${DestinationDbServer},P=${DestinationDbServerPort},u=${DestinationDbUserName},p="${DestinationDbPassword}",D=${DestinationDbName} 2>&1 | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

  if [ $? -eq 0 ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
  else
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi

  pt-table-sync --verbose \
                --where "${PostContentFilter}" \
                --execute h=${SourceDbServer},P=${SourceDbServerPort},u=${SourceDbUserName},p="${SourceDbPassword}",D=${SourceDbName},t=${WPTablePrefix}posts \
                          h=${DestinationDbServer},P=${DestinationDbServerPort},u=${DestinationDbUserName},p="${DestinationDbPassword}",D=${DestinationDbName} 2>&1 | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

  if [ $? -eq 0 ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
  else
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi
fi

if [ "$DBSyncOnly" == "$STATUS_OFF" ]; then
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): + Adjusting data on the destination database ..."
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + WP-CLI run-time parameters:"

  wp --info --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + Links over HTTPS"

  if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
    wp search-replace "https://${SourceDomain}" "https://${DestinationDomain}" \
       --ssh=${SSHTunnelUserName}@${SSHTunnelEndPoint}${DestinationPath} \
       --skip-columns=guid --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  else
    wp search-replace "https://${SourceDomain}" "https://${DestinationDomain}" \
       --skip-columns=guid --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  fi


  if [ $? -eq 0 ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
  else
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi

  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + Links over HTTP"

  if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
    wp search-replace "http://${SourceDomain}" "http://${DestinationDomain}" \
       --ssh=${SSHTunnelUserName}@${SSHTunnelEndPoint}${DestinationPath} \
       --skip-columns=guid --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  else
    wp search-replace "http://${SourceDomain}" "http://${DestinationDomain}" \
       --skip-columns=guid --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  fi

  if [ $? -eq 0 ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
  else
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi

  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + Filesystem paths"

  if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
    wp search-replace "${SourcePath}" "${DestinationPath}" \
       --ssh=${SSHTunnelUserName}@${SSHTunnelEndPoint}${DestinationPath} \
       --skip-columns=guid --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  else
    wp search-replace "${SourcePath}" "${DestinationPath}" \
       --skip-columns=guid --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  fi

  if [ $? -eq 0 ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
  else
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi

  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + Cache flushing"

  if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
    wp cache flush \
       --ssh=${SSHTunnelUserName}@${SSHTunnelEndPoint}${DestinationPath} \
       --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  else
    wp cache flush \
       --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  fi

  if [ $? -eq 0 ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
  else
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi

  if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
    wp w3-total-cache flush \
       --ssh=${SSHTunnelUserName}@${SSHTunnelEndPoint}${DestinationPath} \
       --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  else
    wp w3-total-cache flush \
       --allow-root | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
  fi

  if [ $? -eq 0 ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
  else
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
    ExitCode=$(($ExitCode+1))
  fi
fi

echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): + Verifying and Optimizing destination database:"
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + Checking database ..."

if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
  if [ -z "$(ps -ef | grep ssh | grep ExitOnForwardFailure)" ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     + Reopening SSH Tunnel ..."

    ssh -i ${SSHTunnelKeyFile} \
        -f -o ExitOnForwardFailure=yes \
        -L ${DestinationDbServerPort}:${DestinationDbServer}:${SSHTunnelRemotePort} \
        ${SSHTunnelUserName}@${SSHTunnelEndPoint} \
        sleep ${SSHTunnelTimeOut}
  fi
fi

mysqlcheck -u ${DestinationDbUserName} -p"${DestinationDbPassword}" \
           -h ${DestinationDbServer} -P ${DestinationDbServerPort} ${DestinationDbName} \
           --check 2>&1 | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

if [ $? -eq 0 ]; then
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
else
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi

echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + Auto-reparing database ..."

if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
  if [ -z "$(ps -ef | grep ssh | grep ExitOnForwardFailure)" ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     + Reopening SSH Tunnel ..."

    ssh -i ${SSHTunnelKeyFile} \
        -f -o ExitOnForwardFailure=yes \
        -L ${DestinationDbServerPort}:${DestinationDbServer}:${SSHTunnelRemotePort} \
        ${SSHTunnelUserName}@${SSHTunnelEndPoint} \
        sleep ${SSHTunnelTimeOut}
  fi
fi

mysqlcheck -u ${DestinationDbUserName} -p"${DestinationDbPassword}" \
           -h ${DestinationDbServer} -P ${DestinationDbServerPort} ${DestinationDbName} \
           --auto-repair 2>&1 | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

if [ $? -eq 0 ]; then
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
else
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi

echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):   + Optimizing database ..."

if [ $SSHTunnelEnabled -eq $STATUS_ON ]; then
  if [ -z "$(ps -ef | grep ssh | grep ExitOnForwardFailure)" ]; then
    echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     + Reopening SSH Tunnel ..."

    ssh -i ${SSHTunnelKeyFile} \
        -f -o ExitOnForwardFailure=yes \
        -L ${DestinationDbServerPort}:${DestinationDbServer}:${SSHTunnelRemotePort} \
        ${SSHTunnelUserName}@${SSHTunnelEndPoint} \
        sleep ${SSHTunnelTimeOut}
  fi
fi

mysqlcheck -u ${DestinationDbUserName} -p"${DestinationDbPassword}" \
           -h ${DestinationDbServer} -P ${DestinationDbServerPort} ${DestinationDbName} \
           --optimize 2>&1 | sed "s@^@[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

if [ $? -eq 0 ]; then
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
else
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Restoring original WP-CLI Settings ..."
export WP_CLI_CONFIG_PATH="$WPCLI_CURRENT_SETTINGS"

if [ -f "$TmpDir/.SyncWpDB-$ConfigurationProfile.lock" ] ; then
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Releasing lock ..."

  rm -f "$TmpDir/.SyncWpDB-$ConfigurationProfile.lock"
else
  echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi

echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[Sync-WpDB] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode
