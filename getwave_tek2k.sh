#!/usr/bin/env -S sh
# -*- Mode:Shell-script; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      getwave_tek2k.sh
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Pull a waveform from a Tektronix TDS3000 series oscilloscope.@EOL
# @std       sh mrSCPI
# @deps      mrSCPI gnuplot ruby env(1) sh(1) printf(1)
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
  echo "USE: getwave_tek2k.sh [CHANNEL [PREFIX]]                             "
  echo "                                                                     "
  echo "Works on Tektronix TDS2000 series scopes.                            "
  echo "                                                                     "
  echo "This script will pull the named waveform from the scope, save        "
  echo "the raw output from the SCPI, convert the raw outputs to a CSV,      "
  echo "and draw a text graph of the results.                                "
  echo "                                                                     "
  echo "The filenames are:                                                   "
  echo "                                                                     "
  echo "  - PREFIX_CHANNEL_waveform.pre .... Prefix data from scope          "
  echo "  - PREFIX_CHANNEL_waveform.dat .... Waveform data from scope        "
  echo "  - PREFIX_CHANNEL_waveform.dat .... CSV of waveform                 "
  echo "  - PREFIX_CHANNEL_waveform.gplt ... A GNUPlot file                  "
  echo "                                                                     "
  echo "Valid channel names are CH1, CH2, CH3, CH4, MATH,                    "
  echo "                        REFA, REFB, REFC, and REFD                   "
  echo "                                                                     "
  echo "Default channel is CH1.  Default prefix is a time/date string        "
  echo "                                                                     "
  exit 1
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
CHAN=${1:-CH1}    
FPFX=${2:-`date +%Y%m%d%H%M%S`}    

echo "getwave_tek2k.sh: Attempting to pull waveform from scope"
mrSCPI.rb --url @tek2k                                                                             \
          --echo false                                                                             \
          --result_type nil                                                                        \
          --cmd "DATa:SOUrce $CHAN; DATa:ENCdg ASCII; DATa:WIDth 1; DATa:STARt 1; DATa:STOP 2500"  \
          --result_type :string                                                                    \
          --print_raw_result true                                                                  \
          --out_file "${FPFX}_${CHAN}_waveform.pre"                                                \
          --cmd 'WFMPRe?'                                                                          \
          --out_file "${FPFX}_${CHAN}_waveform.dat"                                                \
          --cmd 'CURVe?'

if [ -s ${FPFX}_${CHAN}_waveform.pre -a -s ${FPFX}_${CHAN}_waveform.dat ]; then

  echo "getwave_tek2k.sh: Converting raw scope data to CSV"
  tdsRAW2CSV.rb -v 7 -p ${FPFX}_${CHAN}_waveform.pre ${FPFX}_${CHAN}_waveform.dat -o ${FPFX}_${CHAN}_waveform.csv
  
  printf "set tics nomirror\nset tics out\nunset key\nset xzeroaxis\nset yzeroaxis\nset term dumb\nset datafile separator ','\nplot '${FPFX}_${CHAN}_waveform.csv' using 1:2 with points\npause mouse\n" | gnuplot

  echo "getwave_tek2k.sh: Waveform saved in ${FPFX}_${CHAN}_waveform.csv"
else
  echo "getwave_tek2k.sh: Failed to capture waveform"
fi
