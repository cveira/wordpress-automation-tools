#!/bin/bash
# -------------------------------------------------------------------------------
# Name:         lock-fstree
# Description:  Locks down a file system subtree with the right set of permissions
# Author:       Carlos Veira Lorenzo - cveira [at] thinkinbig.org
# Version:      3.0b
# Date:         2016/10/28
# -------------------------------------------------------------------------------
# Usage:        lock-fstree.sh <ConfigProfileName> [-confirm] [-?|-h|--help]
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
    echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): ERROR: Can't find a Configuration Profile named $ConfigurationProfile"
    echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   lock-fstree.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"

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
  echo "  lock-fstree.sh <ConfigProfileName> [-confirm] [-?|-h|--help]"
  echo

  exit 0
fi


echo
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Lock-FsTree v3.0b                                                                       "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Carlos Veira Lorenzo - [http://thinkinbig.org]                                             "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): This software come with ABSOLUTELY NO WARRANTY. This is free                               "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): software under GPL 2.0 license terms and conditions.                                       "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Loading configuration ..."

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


if [ -f "$TmpDir/.LockFsTree-$ConfigurationProfile.lock" ] ; then
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Aborting operation."
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   A previous instance is still running."

  exit 0
else
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Acquiring locks ..."

  touch "$TmpDir/.LockFsTree-$ConfigurationProfile.lock"
  touch "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock"
fi


echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Execution parameters: "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   User Confirmation:             $(ConvertTo-String $Confirm) "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Lock Owner:                    $LockOwner "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Lock File ACLs:                $LockFileACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Lock Directory ACLs:           $LockDirACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   UnLock Owner:                  $UnLockOwner "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   UnLock File ACLs:              $UnLockFileACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   UnLock Directory ACLs:         $UnLockDirACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Owner for Exceptions:          $ExceptionOwner "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   File ACLs for Exceptions:      $ExceptionLockFileACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Directory ACLs for Exceptions: $ExceptionLockDirACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Full Control File ACLs:        $FullControlLockFileACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   Full Control Directory:        $FullControlLockDirACL "
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): -------------------------------------------------------------------------------------------"

if [ $Confirm -eq $STATUS_OFF ]; then
  read -p "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Do you want to proceed (y/n) ? " UserConfirmation

  if [ "$UserConfirmation" != "y" ] ; then
    if [ -f "$TmpDir/.LockFsTree-$ConfigurationProfile.lock" ] ; then
      echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Releasing locks ..."

      rm -f "$TmpDir/.LockFsTree-$ConfigurationProfile.lock"
      rm -f "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock"
    else
      echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
    fi

    echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Started:  $StartTime"
    echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Finished: $(date '+%Y/%m/%d %H:%M:%S')"

    exit 0
  fi
fi


cd "$TargetPath"

echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting object onwership ..."

chown -Rv "$LockOwner" "$TargetPath" | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting file ACLs ..."

find "$TargetPath" -depth -type f -print -exec chmod $LockFileACL '{}' \;  | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting folder ACLs ..."

find "$TargetPath" -depth -type d -print -exec chmod $LockDirACL '{}' \;  | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   @g"

if [ $? -eq 0 ]; then
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed"
else
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   > Operation completed with errors"
  ExitCode=$(($ExitCode+1))
fi


echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): + Setting up exceptions ..."

for Exception in $( cat $InstallDir/$ExceptionsFile | grep -v "#" | grep . ); do
  ExecutionMode=`echo $Exception | awk -F ":" '{ print $1 }'`
  SecurityRule=`echo $Exception  | awk -F ":" '{ print $2 }'`
  TargetObject=`echo $Exception  | awk -F ":" '{ print $3 }'`

  case "$ExecutionMode" in
    $TreeMode)
      echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting object onwership ..."

      chown -Rv "$ExceptionOwner" "$TargetObject" | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

      if [ $? -eq 0 ]; then
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
      else
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
        ExitCode=$(($ExitCode+1))
      fi


      if [ "$SecurityRule" == $FullControlRule ] ; then
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        # find "$TargetObject" -depth -type f -print -exec chmod $FullControlLockFileACL '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
        find "$TargetObject" -depth -type d -print -exec chmod $FullControlLockDirACL '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      else
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACLs ..."

        find "$TargetObject" -depth -type f -print -exec chmod $ExceptionLockFileACL  '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi

        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        find "$TargetObject" -depth -type d -print -exec chmod $ExceptionLockDirACL   '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      fi
    ;;

    $FolderMode)
      echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting object onwership ..."

      chown -Rv "$ExceptionOwner" "$TargetObject" | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

      if [ $? -eq 0 ]; then
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
      else
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
        ExitCode=$(($ExitCode+1))
      fi


      if [ "$SecurityRule" == $FullControlRule ] ; then
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        # find "$TargetObject" -type f -print -exec chmod $FullControlLockFileACL '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"
        find "$TargetObject" -type d -print -exec chmod $FullControlLockDirACL '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      else
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACLs ..."

        find "$TargetObject" -type f -print -exec chmod $ExceptionLockFileACL  '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi

        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting folder ACLs ..."

        find "$TargetObject" -type d -print -exec chmod $ExceptionLockDirACL   '{}' \; | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      fi
    ;;

    $FileMode)
      echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting object onwership ..."

      chown -v "$ExceptionOwner" "$TargetObject" | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

      if [ $? -eq 0 ]; then
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
      else
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
        ExitCode=$(($ExitCode+1))
      fi

      if [ "$SecurityRule" == $FullControlRule ] ; then
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACL ..."

        chmod $FullControlLockFileACL "$TargetObject" | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      else
        echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):   + Setting file ACL ..."

        chmod $ExceptionLockFileACL   "$TargetObject" | sed "s@^@[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     @g"

        if [ $? -eq 0 ]; then
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed"
        else
          echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'):     > Operation completed with errors"
          ExitCode=$(($ExitCode+1))
        fi
      fi
    ;;
  esac
done


cd "$OriginalDir"


if [ -f "$TmpDir/.LockFsTree-$ConfigurationProfile.lock" ] ; then
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Releasing locks ..."

  rm -f "$TmpDir/.LockFsTree-$ConfigurationProfile.lock"
  rm -f "$TmpDir/.UnLockFsTree-$ConfigurationProfile.lock"
else
  echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Could not release lock: lock not found."
fi

echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Total errors captured: $ExitCode"
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Started:               $StartTime"
echo "[Lock-FsTree] $(date '+%Y/%m/%d %H:%M:%S'): Finished:              $(date '+%Y/%m/%d %H:%M:%S')"

exit $ExitCode