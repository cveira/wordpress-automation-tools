#!/bin/bash

# Functions =====================================================================


# -------------------------------------------------------------------------------
# Name:         ConvertTo-String
# Description:  Transforms specific integer digits used as 'codes' into the
#               actual human meaning. This is useful to display on the screen the
#               actual runtime paramenters of a script.
# -------------------------------------------------------------------------------
# Usage:        ConvertTo-String <Integer|WhiteSpace>
# -------------------------------------------------------------------------------
# Dependencies: N/A
# -------------------------------------------------------------------------------

function ConvertTo-String {
  case "$1" in
    "0") echo "OFF" ;;
    "1") echo "ON"  ;;
    "")  echo "N/A" ;;
    *)   echo "$1"  ;;
  esac
}
