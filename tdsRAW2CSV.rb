#!/usr/bin/env -S ruby
# -*- Mode:ruby; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      tdsRAW2CSV.rb
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Convert RAW preamble & waveform data from Tektronix TDS 2000 & 3000B series oscilloscopes into a CSV files.@EOL
# @std       Ruby_3
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
require 'optparse'
require 'optparse/time'
require 'fileutils' 
require 'set' 

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Process start time
processStartTime = Time.new

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Print stuff to STDOUT & STDERR immediately -- important on windows
$stdout.sync = true
$stderr.sync = true

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Get options
adjV      = true   # Convert samples to voltage, or just integers
outTitle  = true   # Output titles
outSep    = ','    # Output separator
verbose   = 1      # Verbose level
outFileN  = nil
preFileN  = nil
opts = OptionParser.new do |opts|
  opts.banner = ""
  opts.separator("Transform Tektronix waveform data into CSV                ")
  opts.separator("                                                          ")
  opts.separator("Usage: sdsRAW2CSV.rb [options] -p preamble_file data_file ")
  opts.separator("                                                          ")
  opts.separator(" Input Files:                                             ")
  opts.separator("    preamble_file .. The resuls of a :WFMPRe? call.       ")
  opts.separator("    data_file ...... The resuls of a :CURVe? call.        ")
  opts.separator("                                                          ")
  opts.separator("  Options:                                                ")
  opts.on("-h",      "--help",          "Show this message                  ") { STDERR.puts opts; exit                 }
  opts.on("-v INT",  "--verbose INT",   "Verbose level                      ") { |v| verbose   = v.to_i                 }
  opts.separator("        1 - Errors                                        ")
  opts.separator("        2 - Warnings                                      ")
  opts.separator("        3 - Progress (DEFAULT)                            ")
  opts.separator("        5 - Arguments                                     ")
  opts.separator("        7 - Metadata                                      ")
  opts.on("-t Y/N",  "--title Y/N",     "Print titles (DEFAULT: Y)          ") { |v| outTitle  = !!(v.match(/^[yt1]/i)) }
  opts.on("-s SEP",  "--separator SEP", "Separator (DEFAULT: comma)         ") { |v| outSep    = v                      }
  opts.on("-p FILE", "--preamble FILE", "File containing preamble data      ") { |v| preFileN  = v                      }
  opts.on("-o FILE", "--output FILE",   "Output file                        ") { |v| outFileN  = v                      }
  opts.separator("                                                          ")
  opts.separator("Only tested on the TDS2000 & TDS3000B series.             ")
  opts.separator("                                                          ")
end
opts.parse!(ARGV)

if ( !(outFileN)) then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - ERROR(1): Must provide an output file!\n\n")
  STDERR.puts(opts)
  exit
end

if ( !(preFileN)) then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - ERROR(1): Must provide a preamble file!\n\n")
  STDERR.puts(opts)
  exit
end

outFileD = nil
if (outFileD == '-') then
  outFileD = STDOUT
else
  outFileD = open(outFileN, "wb");
end

dataFileName = nil
if (ARGV.length < 1) then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - ERROR(1): Must provide a waveform data file!\n\n")
  STDERR.puts(opts)
  exit
elsif (ARGV.length > 1) then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - ERROR(1): May provide only one waveform data file!\n\n")
  STDERR.puts(opts)
  exit
else
  dataFileName = ARGV[0]
end

if verbose >= 5 then  
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(5): outTitle ....... #{outTitle.inspect     }")
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(5): outSep ......... #{outSep.inspect       }")
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(5): verbose ........ #{verbose.inspect      }")
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(5): outFileN ....... #{outFileN.inspect     }")
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(5): preFileN ....... #{preFileN.inspect     }")
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(5): dataFileName ... #{dataFileName.inspect }")
end
 
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(3): Read, Parse, & Extract preamble data")
end

preamble_data_hash  = ['BYT_Nr', 'BIT_Nr', 'ENCdg', 'BN_Fmt', 
                       'BYT_Or', 'NR_Pt',  'WFID',  'PT_FMT',
                       'XINcr',  'PT_Off', 'XZERo', 'XUNit',
                       'YMUlt',  'YZEro',  'YOFf',  'YUNit'].zip(File.read(preFileN, :encoding=>'binary').strip.split(';').map {|x| x.strip.sub(/^.*  */, '')}).to_h

# Report on preamble data
if verbose >= 7 then  
  ['BN_Fmt', 'BYT_Nr', 'BYT_Or', 'ENCdg', 'PT_FMT', 'PT_Off', 'XINcr', 'XZERo', 'YMUlt', 'YOFf', 'YZERo'].each do |k|
    STDERR.printf("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(7): %9s : %s\n", k, preamble_data_hash[k])
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(3): Reading and converting Y data")
end
yDataPts = nil
if (preamble_data_hash['ENCdg'] == 'BIN') then
  if (preamble_data_hash['BYT_Nr'] == '1') then
    if (preamble_data_hash['BN_Fmt'] == 'RP') then    
      wave_unpack_code = 'C*'               # 1 byte, Unsigned, no-endian
    else
      wave_unpack_code = 'c*'               # 1 byte, Signed,   no-endian
    end
  else
    if (preamble_data_hash['BYT_Or'] == 'LSB') then
      if (preamble_data_hash['BN_Fmt'] == 'RP') then    
        wave_unpack_code = 'S<*'            # 2 byte, Unsigned, little-endian
      else
        wave_unpack_code = 's<*'            # 2 byte, Signed,   little-endian
      end
    else
      if (preamble_data_hash['BN_Fmt'] == 'RP') then  
        wave_unpack_code = 'S>*'            # 2 byte, Unsigned, big-endian
      else
        wave_unpack_code = 's>*'            # 2 byte, Signed,   big-endian
      end
    end
  end
  # Binary waveform data starts with a variable length ASCII header starting!!  The header starts with the literal '#' character.  This is followed by a
  # single ASCII digit indicating the number of digits that follow.  The remaining characters are ASCII digits indicating the number of bytes that follow.  We
  # use this length to avoid converting any extra data at the end of the record (like a newline).
  tmp = File.read(dataFileName, :encoding=>'binary')
  yDataPts = tmp[(2+tmp[1].to_i)..((1+tmp[1].to_i) + tmp[2..(1+tmp[1].to_i)].to_i)].unpack(wave_unpack_code)
else
  yDataPts = File.read(dataFileName, :encoding=>'binary').chomp.sub(/^.*:CURVE */, '').split(',')
end

if verbose >= 3 then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(3): Found #{yDataPts.length} points")
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(3): Printing Data")
end

if outTitle then
  if (preamble_data_hash['PT_FMT'] == 'Y') then
    outFileD.puts("t#{outSep}v")
  else
    outFileD.puts("t#{outSep}v1#{outSep}v2")
  end
end

xData = 1
while (xData <= yDataPts.length) do
  yData = yDataPts[xData - 1]
  xpt = preamble_data_hash['XZERo'].to_f + ( xData.to_f - preamble_data_hash['PT_Off'].to_f ) * preamble_data_hash['XINcr'].to_f 
  ypt = preamble_data_hash['YZERo'].to_f + ( yData.to_f - preamble_data_hash['YOFf'].to_f   ) * preamble_data_hash['YMUlt'].to_f
  xData += 1
  if (preamble_data_hash['PT_FMT'] == 'Y') then
    outFileD.printf("%0.5g#{outSep}%0.5g\n", xpt, ypt)
  else
    yData = yDataPts[xData - 1]
    ypt2 = preamble_data_hash['YZERo'].to_f + ( yData.to_f - preamble_data_hash['YOFf'].to_f   ) * preamble_data_hash['YMUlt'].to_f
    outFileD.printf("%0.5g#{outSep}%0.5g#{outSep}%0.5g\n", xpt, ypt, ypt2)
    xData += 1;
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(3): Total runtime: #{Time.new - processStartTime}")
  STDERR.puts("tdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - INFO(3): Finished")
end
