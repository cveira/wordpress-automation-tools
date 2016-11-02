#!/bin/bash
# -------------------------------------------------------------------------------
# Name:         unlock-fstree
# Description:  Unlocks a file system subtree with the right set of permissions
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      3.0b
# Date:         2016/10/28
# -------------------------------------------------------------------------------
# Usage:        unlock-fstree.sh <ConfigProfileName> [-confirm] [-?|-h|--help]
# -------------------------------------------------------------------------------
# Dependencies: cat, ls, head, rm, wc, tr, touch, grep, awk, sed, date, find,
#               chmod, chown
#               lock-fstree-<ConfigProfileName>.conf
#               lock-fstree-<ConfigProfileName>-exceptions.conf
# -------------------------------------------------------------------------------

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
TargetPath="TargetPath"
ExceptionsFile="ExceptionsFile"
LockOwner="LockOwner"
LockFileACL="LockFileACL"
LockDirACL="LockDirACL"
UnLockOwner="UnLockOwner"
UnLockFileACL="UnLockFileACL"
UnLockDirACL="UnLockDirACL"
ExceptionOwner="ExceptionOwner"
ExceptionLockFileACL="ExceptionLockFileACL"
ExceptionLockDirACL="ExceptionLockDirACL"
FullControlLockFileACL="FullControlLockFileACL"
FullControlLockDirACL="FullControlLockDirACL"

TreeMode="tree"
FolderMode="folder"
FileMode="file"
FullControlRule="FullControl"


# Establish a SessionId and the StartTime
CurrentDate=$(date +%Y%m%d-%H%M%S)
CurrentSequenceId=$(ls -1AB $LogsDir/*$CurrentDate* 2> /dev/null | wc -l)
CurrentSessionId="$CurrentDate-$CurrentSequenceId"
StartTime="$(date '+%Y/%m/%d %H:%M:%S')"


# Load support functions and variables
. $InstallDir/libcore.sh


# Evaluate and Process CLI parameters
if [ -z $(echo "$1" | grep '^-') ] ; then
  if [ ! -f $InstallDir/"lock-fstree-$ConfigurationProfile.conf" ] ; then
    echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
    echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   unlock-fstree.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"

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
  echo "  unlock-fstree.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): UnLock-FsTree v3.0b                                                                       "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Loading configuration ..."

for ConfigurationItem in $( cat "$InstallDir/lock-fstree-$ConfigurationProfile.conf" | grep -v "#" | grep . ); do
  PropertyName=`echo $ConfigurationItem  | awk -F "=" '{ print $1 }'`
  PropertyValue=`echo $ConfigurationItem | awk -F "=" '{ print $2 }'`

  if [ $PropertyName == $TargetPath             ] ; then TargetPath="$PropertyValue"             ; fi
  if [ $PropertyName == $ExceptionsFile         ] ; then ExceptionsFile="$PropertyValue"         ; fi
  if [ $PropertyName == $LockOwner              ] ; then LockOwner="$PropertyValue"              ; fi
  if [ $PropertyName == $LockFileACL            ] ; then LockFileACL="$PropertyValue"            ; fi
  if [ $PropertyName == $LockDirACL             ] ; then LockDirACL="$PropertyValue"             ; fi
  if [ $PropertyName == $UnLockOwner            ] ; then UnLockOwner="$PropertyValue"            ; fi
  if [ $PropertyName == $UnLockFileACL          ] ; then UnLockFileACL="$PropertyValue"          ; fi
  if [ $PropertyName == $UnLockDirACL           ] ; then UnLockDirACL="$PropertyValue"           ; fi
  if [ $PropertyName == $ExceptionOwner         ] ; then ExceptionOwner="$PropertyValue"         ; fi
  if [ $PropertyName == $ExceptionLockFileACL   ] ; then ExceptionLockFileACL="$PropertyValue"   ; fi
  if [ $PropertyName == $ExceptionLockDirACL    ] ; then ExceptionLockDirACL="$PropertyValue"    ; fi
  if [ $PropertyName == $FullControlLockFileACL ] ; then FullControlLockFileACL="$PropertyValue" ; fi
  if [ $PropertyName == $FullControlLockDirACL  ] ; then FullControlLockDirACL="$PropertyValue"  ; fi
done


if [ -f "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock" ] ; then
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring locks ..."

  touch "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock"
  touch "$TmpDir/.LockFsTree-$ConfigurationProfile.lock"
fi


echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation:             $(ConvertTo-String $Confirm) "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Lock Owner:                    $LockOwner "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Lock File ACLs:                $LockFileACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Lock Directory ACLs:           $LockDirACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   UnLock Owner:                  $UnLockOwner "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   UnLock File ACLs:              $UnLockFileACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   UnLock Directory ACLs:         $UnLockDirACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Owner for Exceptions:          $ExceptionOwner "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   File ACLs for Exceptions:      $ExceptionLockFileACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Directory ACLs for Exceptions: $ExceptionLockDirACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Full Control File ACLs:        $FullControlLockFileACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Full Control Directory:        $FullControlLockDirACL "
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

if [ $Confirm -eq $STATUS_OFF ]; then
  read -p "[UnUnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    if [ -f "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock" ] ; then
      echo "[UnUnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Releasing locks ..."

      rm -f "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock"
      rm -f "$TmpDir/.LockFsTree-$ConfigurationProfile.lock"
    else
      echo "[UnUnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[UnUnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[UnUnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


cd "$TargetPath"

echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting object onwership ..."

chown -Rv "$UnLockOwner" "$TargetPath" | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting file ACLs ..."

find "$TargetPath" -depth -type f -print -exec chmod $UnLockFileACL '{}' \;  | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting folder ACLs ..."

find "$TargetPath" -depth -type d -print -exec chmod $UnLockDirACL '{}' \;  | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting up exceptions ..."

for Exception in $( cat $InstallDir/$ExceptionsFile | grep -v "#" | grep . ); do
  ExecutionMode=`echo $Exception | awk -F ":" '{ print $1 }'`
  SecurityRule=`echo $Exception  | awk -F ":" '{ print $2 }'`
  TargetObject=`echo $Exception  | awk -F ":" '{ print $3 }'`

  case "$ExecutionMode" in
    $TreeMode)
      echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting object onwership ..."

      chown -Rv "$ExceptionOwner" "$TargetObject" | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

      if [ $? -eq 0 ]; then
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
      else
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
        ExitCode=$(($ExitCode+1))
      fi


      if [ "$SecurityRule" == $FullControlRule ] ; then
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        # find "$TargetObject" -depth -type f -print -exec chmod $FullControlLockFileACL '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
        find "$TargetObject" -depth -type d -print -exec chmod $FullControlLockDirACL '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      else
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACLs ..."

        find "$TargetObject" -depth -type f -print -exec chmod $ExceptionLockFileACL  '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi

        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        find "$TargetObject" -depth -type d -print -exec chmod $ExceptionLockDirACL   '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      fi
    ;;

    $FolderMode)
      echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting object onwership ..."

      chown -Rv "$ExceptionOwner" "$TargetObject" | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

      if [ $? -eq 0 ]; then
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
      else
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
        ExitCode=$(($ExitCode+1))
      fi


      if [ "$SecurityRule" == $FullControlRule ] ; then
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        # find "$TargetObject" -type f -print -exec chmod $FullControlLockFileACL '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
        find "$TargetObject" -type d -print -exec chmod $FullControlLockDirACL '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      else
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACLs ..."

        find "$TargetObject" -type f -print -exec chmod $ExceptionLockFileACL  '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi

        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        find "$TargetObject" -type d -print -exec chmod $ExceptionLockDirACL   '{}' \; | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      fi
    ;;

    $FileMode)
      echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting object onwership ..."

      chown -v "$ExceptionOwner" "$TargetObject" | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

      if [ $? -eq 0 ]; then
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
      else
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
        ExitCode=$(($ExitCode+1))
      fi

      if [ "$SecurityRule" == $FullControlRule ] ; then
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACL ..."

        chmod $FullControlLockFileACL "$TargetObject" | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      else
        echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACL ..."

        chmod $ExceptionLockFileACL   "$TargetObject" | sed "s@^@[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      fi
    ;;
  esac
done


cd "$OriginalDir"


if [ -f "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock" ] ; then
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Releasing locks ..."

  rm -f "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock"
  rm -f "$TmpDir/.LockFsTree-$ConfigurationProfile.lock"
else
  echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi

echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[UnLock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode