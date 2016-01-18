#!/bin/bash
# Script name:          check_lin_process.sh
# Version:              v2.06.160116
# Created on:           17/08/2015
# Author:               Willem D'Haese
# Purpose:              Bash script that counts processes and returns total
#                       memory and cpu perfdata.
# On GitHub:            https://github.com/willemdh/check_lin_process
# On OutsideIT:         http://outsideit.net/check-lin-process
# Recent History:
#   22/12/15 => Subtract 2 from process count and critical if 0
#   05/01/16 => Added Minimum and Maximum process count, replaced getopt
#   07/01/16 => Better process count, added noheader and ps -C
#   16/01/16 => Added average CPU option and more detailed output
#   18/01/16 => Fixed bug with CountMaxExitcode 
# Copyright:
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version. This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details. You should have received a copy of the
# GNU General Public License along with this program.  If not, see
# <http://www.gnu.org/licenses/>.

Verbose=0

WriteLog () {
  if [ -z "$1" ] ; then echo "WriteLog: Log parameter #1 is zero length. Please debug..." ; exit 1
  else
    if [ -z "$2" ] ; then echo "WriteLog: Severity parameter #2 is zero length. Please debug..." ; exit 1
    else
      if [ -z "$3" ] ; then echo "WriteLog: Message parameter #3 is zero length. Please debug..." ; exit 1 ; fi
    fi
  fi
  Now=$(date '+%Y-%m-%d %H:%M:%S,%3N')
  if [ $1 = "Verbose" -a $Verbose = 1 ] ; then echo "$Now: $2: $3"
  elif [ $1 = "Verbose" -a $Verbose = 0 ] ; then :
  elif [ $1 = "Output" ] ; then echo "${Now}: $2: $3"
  elif [ -f $1 ] ; then echo "${Now}: $2: $3" >> $1
  fi
}

Process=""
Name=""
Warning=""
Critical=""
Minimum=0
Maximum=100
ProcessCount=0
Exitcode=3
Output=""
CountMinExitcode=0
CountMaxExitcode=0

while :; do
    case "$1" in
        -h|--help)
            DisplayHelp="true" ; shift ; ;;
        -p|--Process)
            shift ; Process="$1" ; shift ; ;;
        -N|--Name)
            shift ; Name="$1" ; shift ; ;;
        -w|--Warning)
            shift ; Warning="$1" ; shift ; ;;
        -c|--Critical)
            shift ; Critical="$1" ; shift ; ;;
        -m|--Minimum)
            shift ; Minimum="$1" ; shift ; ;;
        -M|--Maximum)
            shift ; Maximum="$1" ; shift ; ;;
        -C|-Count)
            shift ; Count="$1" ; shift ; ;;
        -A|--AverageCpu)
            AverageCpu="true" ; shift ; ;;
        -*)
            echo "you specified a non-existant option. Please debug." ; exit 2 ; ;;
        *)
            break ; ;;
    esac
done

if [[ "$DisplayHelp" == "true" ]] ; then
    echo "
        -h|--help,         Display help information
        -N|--Name,         Specify a fancy name for the process
        -p|--Process,      Specify a process to be monitored
        -w|--Warning,      Specify a warning level for the check, default is 60%
        -c|--Critical,     Specify a critical level for the check, default is 70%
        -m|--Minimum,      Minimum number of processes expected to run, default 0
        -M|--Maximum,      Maximum amount of processes expected to run, default 100
        -A|--AverageCpu,   Divide process cpu count by the number of process cores
        -C|--Count,        Method to define process find (To do)"
    exit 0
fi
if [[ "$Process" == "" ]] ; then
    echo "No process was specified. The '-p' switch must be used to specify the process"
    exit 3
fi

if [[ "$Name" == "" ]] ; then
    Name=$Process
fi
CpuCount=$(cat /proc/cpuinfo | grep processor | wc -l)
WriteLog Verbose Info "CPU Cores: $CpuCount"
CheckCpu=$(ps -C $Process -o%cpu= | paste -sd+ | bc)
WriteLog Verbose Info "CPU Total %: $CheckCpu"
if [[ "$AverageCpu" == "true" ]] ; then
	CheckCpu=$(echo "$CheckCpu/$CpuCount" | bc -l)
	WriteLog Verbose Info "CPU Averaged: $CheckCpu"
fi
RoundedCpuResult=$(echo $CheckCpu | awk '{print int($1+0.5)}')
WriteLog Verbose Info "CPU Rounded: $RoundedCpuResult"
CheckMem=$(ps -C $Process -o%mem= | paste -sd+ | bc)
RoundedMemResult=$(echo $CheckMem | awk '{print int($1+0.5)}')
RealProcessCount=$(ps -C $Process --no-heading | wc -l)
# ps -ef to retrieve the process count was in fact incorrect
#ProcessCount=`ps -ef | grep -v grep | grep $Process | wc -l`
#RealProcessCount=$(($ProcessCount-2))
if [[ "$Warning" == "" ]] ; then
    Warning=60
fi
if [[ "$Critical" == "" ]] ; then
    Critical=70
fi
WriteLog Verbose Info "Rounded CPU Result: $RoundedCpuResult , ROunde Memory Result: $RoundedMemResult" 
if [ "$RoundedCpuResult" == "" -o "$RoundedMemResult" == "" ] ; then
        Output="The $Name process doesn't appear to be running, as CPU or memory is undefined. Please debug. "
	Exitcode=2 ;
else
    if [[ $RealProcessCount -lt $Minimum ]] ; then
        Output="${Output}$Name process count of $RealProcessCount is lesser then Minimum threshold of ${Minimum}. "
        CountMinExitcode=2
    fi
    if [[ $RealProcessCount -gt $Maximum ]] ; then
        Output="${Output}$Name process count of $RealProcessCount is larger then Maximum threshold of ${Maximum}. "
        CountMaxExitcode=2
    fi
    if [ "$RoundedCpuResult" -ge "$Critical" ] ; then
        Output="${Output}$Name CPU usage exceeded critical threshold. "
        Exitcode=2
    elif [ "$RoundedCpuResult" -ge "$Warning" ] ; then
        Output="${Output}$Name CPU usage exceeded warning threshold. "
        Exitcode=1
    fi
    if [ "$RoundedMemResult" -ge "$Critical" ] ; then
        Output="${Output}$Name memory usage exceeded critical threshold. "
        Exitcode=2
    elif [ "$RoundedMemResult" -ge "$Warning" ] ; then
        Output="${Output}$Name memory usage exceeded warning threshold. "
        Exitcode=1
    fi
    if [ "$RoundedCpuResult" -lt "$Warning" -a "$RoundedMemResult" -lt "$Warning" ] ; then
        WriteLog Verbose Info "OK? RoundedCpuResult: $RoundedCpuResult , RoundedMemResult: $RoundedMemResult Warning: $Warning Critical: $Critical CountExitcode: $CountExitcode CountMinExitcode: $CountMinExitcode CountExitMaxcode: $CountExitMaxcode" 
        if [ $CountMinExitcode -eq 2 -o $CountMaxExitcode -eq 2 ] ; then
            Exitcode=2
        else
            Output="${Output}$Name "
            Exitcode=0
        fi 
    fi
    Details="{CPU: ${RoundedCpuResult}%}{Memory: ${RoundedMemResult}%}{Count: ${RealProcessCount}}} | ${Name}_cpu=$RoundedCpuResult ${Name}_mem=$RoundedMemResult ${Name}_count=$RealProcessCount"
fi

case "$Exitcode" in
    0) Output="OK: ${Output}$Details" ;;
    1) Output="WARNING: ${Output}$Details" ;;
    2) Output="CRITICAL: ${Output}$Details" ;;
    3) Output="UNKNOWN: ${Output}$Details" ;;
    *) Output="UNKNOWN: Exitcode ${Exitcode}. ${Output}$Details" ;;
esac
echo $Output
exit $Exitcode
