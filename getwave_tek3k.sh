#!/usr/bin/env -S sh
# -*- Mode:Shell-script; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      getwave_tek3k.sh
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Pull a waveform from a Tektronix TDS3000 series oscilloscope.@EOL
# @std       sh mrSCPI
# @deps      mrSCPI gnuplot ruby curl env(1) sh(1) printf(1) 
# @copyright 
#  @parblock
#  Copyright (c) 2023, Mitchell Jay Richling <http://www.mitchr.me/> All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice, this list of conditions, and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions, and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#
#  3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without
#     specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
#  TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  @endparblock
#########################################################################################################################################################.H.E.##

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if [ "$1" = "-h" -o "$1" = "--help" -o "$1" = "-help" ]; then
  echo "                                                                     "
  echo "USE: getwave_tek3k.sh [CHANNEL [PREFIX]]                             "
  echo "                                                                     "
  echo "Works on Tektronix TDS3000B series scopes.                           "
  echo "                                                                     "
  echo "This script will pull the named waveform from the scope using the    "
  echo "web interface as a CSV file, and draw a text graph of the results.   "
  echo "                                                                     "
  echo "The filenames are:                                                   "
  echo "                                                                     "
  echo "  - PREFIX_CHANNEL_waveform.dat .... CSV of waveform                 "
  echo "  - PREFIX_CHANNEL_waveform.gplt ... A GNUPlot file                  "
  echo "                                                                     "
  echo "Valid channel names are CH1, CH2, CH3, CH4, MATH, MATH1,             "
  echo "                        REF1, REF2, REF3, and REF4                   "
  echo "                                                                     "
  echo "Default channel is CH1.  Default prefix is a time/date string        "
  echo "                                                                     "
  echo "Note 1: Unlike my other 'getwave_' scripts, this one doesn't produce "
  echo "        a .pre and .dat file -- just a .csv.                         "
  echo "Note 2: This script only uses mrSCPI to resolve the IP address of    "
  echo "        the scope.  Instead of using mrSCPI, we use the scope's      "
  echo "        web interface to get the CSV file.  This works really well   "
  echo "        because of the tiny record length of this scope.             "
  echo "                                                                     "
  exit 1
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
CHAN=${1:-ch1}  
FPFX=${2:-`date +%Y%m%d%H%M%S`}    

echo "getwave_tek3k.sh: Attempting to pull waveform from scope"
curl -X POST --data "command=select:${CHAN} on&command=save:waveform:fileformat spreadsheet&wfmsend=Get" `teAlias.rb @tek3kw`'/getwfm.isf' | tr -d '\015' | sed -e '1i t,v' > ${FPFX}_${CHAN}_waveform.csv

if [ -s ${FPFX}_${CHAN}_waveform.csv ]; then
  echo "getwave_tek3k.sh: Plotting CSV"
  printf "set tics nomirror\nset tics out\nunset key\nset xzeroaxis\nset yzeroaxis\nset term dumb\nset datafile separator ','\nplot '${FPFX}_${CHAN}_waveform.csv' using 1:2 with points\n" >  ${FPFX}_${CHAN}_waveform.gplt
  gnuplot -c  ${FPFX}_${CHAN}_waveform.gplt
  echo "getwave_tek3k.sh: Waveform saved in ${FPFX}_${CHAN}_waveform.csv"
else
  echo "getwave_tek3k.sh: Failed to capture waveform"
fi

