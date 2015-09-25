#!/bin/bash

# Script name:          check_lin_process.sh
# Version:              v1.01.150924
# Created on:           17/08/2015
# Author:               Willem D'Haese
# Purpose:              Bash script that counts processes and returns total memory and cpu perfdata
# On GitHub:            https://github.com/willemdh/check_lin_process
# On OutsideIT:         http://outsideit.net/check-lin-process
# Recent History:
#       17/08/15 => Creation date, based on Eli Keimig's check_process_resources.sh
#       18/09/15 => Full integration of cpu, memory, process count and perfdata
#       24/09/15 => Cleanup and prep for GitHub release
# Copyright:
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
# License for more details. You should have received a copy of the GNU General Public License along with this
# program.  If not, see <http://www.gnu.org/licenses/>.

displayhelp="false"
runcheck=""
checkresult=""
hostname=""
process=""
fancyname=""
check=""
warning=""
critical=""

optstr=hH:p:N:C:w:c:

while getopts $optstr Switchvar
do
        case $Switchvar in
                c) critical=$OPTARG ;;
                w) warning=$OPTARG ;;
                C) check=$OPTARG ;;
                N) fancyname=$OPTARG ;;
                p) process=$OPTARG ;;
                H) hostname=$OPTARG ;;
                h) displayhelp="true" ;;
        esac
done
shift $(( $OPTIND - 1 ))

if [ "$displayhelp" == "true" ] ;then
        echo "Script: check_lin_process.sh
Parameters:
        -C,             Specify a check type: CPU or Memory, default check type is Memory
        -c,             Specify a critical level for the check, default is 70%
        -H,             Specify hostname
        -h,             Display help information
        -N,             Specify a fancy name for the process
        -p,             Specify a process to be monitored
        -w,             Specify a warning level for the check, default is 60%"
        exit
fi

if [ "$process" == "" ] ;then
        echo "No process was specified. The '-p' switch must be used to specify the process"
        exit 3
fi

if [ "$fancyname" == "" ] ;then
        fancyname=$process
fi

if [ "$check" != "" ] ;then
        if [ "$check" == "cpu" ] || [ "$check" == "Cpu" ] || [ "$check" == "CPU" ] ;then
                check="cpu"
        elif [ "$check" == "memory" ] || [ "$check" == "Memory" ] || [ "$check" == "MEMORY" ] ;then
                check="mem"
        fi
else
        check="all"
fi

if [ "$check" == "cpu" ] ;then
        runcheckcpu=`ps -C $process -o%cpu= | paste -sd+ | bc`
        roundedcpuresult=`echo $runcheckcpu | awk '{print int($1+0.5)}'`
elif [ "$check" == "mem" ] ;then
        runcheckmem=`ps -C $process -o%mem= | paste -sd+ | bc`
        roundedmemresult=`echo $runcheckmem | awk '{print int($1+0.5)}'`
elif [ "$check" == "all" ] ;then
        runcheckcpu=`ps -C $process -o%cpu= | paste -sd+ | bc`
        roundedcpuresult=`echo $runcheckcpu | awk '{print int($1+0.5)}'`
        runcheckmem=`ps -C $process -o%mem= | paste -sd+ | bc`
        roundedmemresult=`echo $runcheckmem | awk '{print int($1+0.5)}'`
        proccount=`ps -ef | grep -v grep | grep $process | wc -l`
else
        echo "There is an error with your check's syntax. Please debug.."
        exit 3
fi

if [ "$warning" == "" ] ;then
        warning=60
fi
if [ "$critical" == "" ] ;then
        critical=70
fi

if [ "$roundedcpuresult" == "" -o  "$roundedmemresult" == "" ] ;then
        echo "The "$fancyname" process doesn't appear to be running. Please debug."
        exit 3
fi

if [ "$roundedcpuresult" -ge "$critical"  -o  "$roundedmemresult" -ge "$critical" ] ;then
        echo "CRITICAL: $fancyname {CPU: ${roundedcpuresult}%}{Memory: ${roundedmemresult}%}{Count: ${proccount}}} | ${fancyname}_cpu=$roundedcpuresult ${fancyname}_mem=$roundedmemresult ${fancyname}_count=$proccount"
        exit 2
elif [ "$roundedcpuresult" -ge "$warning" -a "$roundedcpuresult" -ge "$warning" ] ;then
        echo "WARNING: $fancyname {CPU: ${roundedcpuresult}%}{Memory: ${roundedmemresult}%}{Count: ${proccount}}} | ${fancyname}_cpu=$roundedcpuresult ${fancyname}_mem=$roundedmemresult ${fancyname}_count=$proccount"
        exit 1
elif [ "$roundedcpuresult" -lt "$warning" -o  "$roundedmemresult" -lt "$warning" ] ;then
        echo "OK: $fancyname {CPU: ${roundedcpuresult}%}{Memory: ${roundedmemresult}%}{Count: ${proccount}}} | ${fancyname}_cpu=$roundedcpuresult ${fancyname}_mem=$roundedmemresult ${fancyname}_count=$proccount"
        exit 0
fi

exit 3