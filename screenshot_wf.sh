#!/usr/bin/env -S sh
# -*- Mode:Shell-script; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      screenshot_wf.sh
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Grab PNG image(s) of the WaveForms window(s).@EOL
# @std       sh
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
  echo "USE: screenshot_wf.sh                                                "
  echo "                                                                     "
  echo "Works on Linux systems running the Digilent WaveForms software       "
  echo "                                                                     "
  echo "This script will grab an image of the WaveForms window(s) and save   "
  echo "the results in file(s) named DATE_wf_window_WINID, where DATE is     "
  echo "a date/time string, and WINID is the X11 window ID.                  "
  echo "                                                                     "
  exit 1
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
dt=`date +%Y%m%d%H%M%S`
ids=`xwininfo -root -tree | grep 'WaveForms .*(new workspace' | awk '{print $1}'`
if [ -z "$id" ] ; then
  echo "No Waveforms windows found!"
  exit 1
else
  cnt=`echo $ids | wc -w`
  idx=1
  for id in $ids; do 
    fn=${dt}_wf_window_$id.png
    echo "Screenshot file ($idx of $cnt): $fn"
    import -window $id $fn
    idx=`expr $idx + 1`
  done
  exit 0
fi
