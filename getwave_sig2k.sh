#!/usr/bin/env -S sh
# -*- Mode:Shell-script; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      getwave_sig2k.sh
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Pull a waveform of less than 10M points from a Sigilent SDS2000XP series scope.@EOL
# @std       sh mrSCPI
# @see       getwave_sig2k.rb
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
  echo "USE: getwave_sig2k.sh [CHANNEL [PREFIX]]                             "
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
  echo "Valid channel names are C1, C2, C3, C4, F1, F2, D0, D1, ..., D15     "
  echo "                                                                     "
  echo "Default channel is C1.  Default prefix is a time/date string         "
  echo "                                                                     "
  echo "WARNING: This script will pull at most 10,000,000 points for a single"
  echo "waveform.  Therefore if you want is on the screen, lower the         "
  echo "scope's memory depth to below 10M points per waveform.  The Ruby     "
  echo "script with the same name handles longer waveforms and pulling data  "
  echo "from waveform history.                                               "
  echo "                                                                     "
  exit 1
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
CHAN=${1:-C1}  
FPFX=${2:-`date +%Y%m%d%H%M%S`}    

echo "getwave_sig2k.sh: Pulling data from scope"
mrSCPI.rb --url @sig2k                                                                                        \
          --echo false                                                                                        \
          --result_type nil                                                                                   \
          --cmd ":WAVeform:SOURce ${CHAN}; :WAVeform:POINt 10000000; :WAVeform:STARt 0; :WAVeform:INTerval 1" \
          --print_raw_result true                                                                             \
          --result_type :string                                                                               \
          --out_file ${FPFX}_${CHAN}_'waveform.pre'                                                           \
          --cmd ':WAVeform:PREamble?'                                                                         \
          --out_file ${FPFX}_${CHAN}_'waveform.dat'                                                           \
          --read_timeout_first_byte 2000                                                                      \
          --cmd ':WAVeform:DATA?'

if [ -s ${FPFX}_${CHAN}_waveform.pre -a -s ${FPFX}_${CHAN}_waveform.dat ]; then
  echo "getwave_sig2k.sh: Converting scope data to CSV"
  sdsRAW2CSV.rb -n 0 ${FPFX}_${CHAN}_waveform.pre ${FPFX}_${CHAN}_waveform.dat -o ${FPFX}_${CHAN}_waveform.csv

  echo "getwave_sig2k.sh: Plotting CSV"
  printf "set tics nomirror\nset tics out\nunset key\nset xzeroaxis\nset yzeroaxis\nset term dumb\nset datafile separator ','\nplot '${FPFX}_${CHAN}_waveform.csv' using 1:2 with points\n" >  ${FPFX}_${CHAN}_waveform.gplt
  gnuplot -c  ${FPFX}_${CHAN}_waveform.gplt

  echo "getwave_sig2k.sh: Waveform saved in ${FPFX}_${CHAN}_waveform.csv"
  exit 0
else
  echo "getwave_sig2k.sh: Failed to capture waveform"
  exit 2
fi

