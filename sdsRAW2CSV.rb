#!/usr/bin/env -S ruby
# -*- Mode:ruby; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      sdsRAW2CSV.rb
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Convert RAW preamble & waveform data from Siglent SDS2000X+ series oscilloscopes into a CSV files.@EOL
# @std       Ruby 3
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
# Print stuff to STDOUT & STDERR immediately -- important on windows
$stdout.sync = true
$stderr.sync = true

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Get options
outTime   = true   # Output time or time and voltage
adjV      = true   # Convert samples to voltage, or just integers
outTitle  = true   # Output titles
outSep    = ','    # Output separator
verbose   = 4      # Verbose level
outFileN  = nil
preFileN  = nil
opts = OptionParser.new do |opts|
  opts.banner = ""
  opts.separator("Transform Siglent waveform data into a CSV file                      ")
  opts.separator("                                                                     ")
  opts.separator("Usage: sdsRAW2CSV.rb [options] -p preamble_file data_file...         ")
  opts.separator("                                                                     ")
  opts.separator(" The script requires two kinds of files as input:                    ")
  opts.separator("  - Waveform data .. The result of :WAVeform:DATA? commands          ")
  opts.separator("                     Waveform data files are the final arguments     ")
  opts.separator("                     to the script.  Each file provided becomes a    ")
  opts.separator("                     voltage column in the CSV file.                 ")
  opts.separator("  - Preamble data .. The result of a :WAVeform:PREamble? command     ")
  opts.separator("                     The file is provided via the -p option, and     ")
  opts.separator("                     applies to all waveform files.                  ")
  opts.separator("                                                                     ")
  opts.separator("  Options:                                                           ")
  opts.on("-h",      "--help",          "Show this message                             ") { STDERR.puts(opts); exit               }
  opts.on("-v INT",  "--verbose INT",   "Verbose level                                 ") { |v| verbose  = v.to_i                 }
  opts.separator("        1 .. Errors                                                  ")
  opts.separator("        3 .. Progress                                                ")
  opts.separator("        4 .. Report on used preamble data (DEFAULT)                  ")
  opts.separator("        5 .. Detailed Progress                                       ")
  opts.separator("        6 .. Report on unused preamble data                          ")
  opts.on("-t Y/N",  "--time Y/N",      "Output time data (DEFAULT: Y)                 ") { |v| outTime  = !!(v.match(/^[yt1]/i)) }
  opts.on("-i Y/N",  "--ints Y/N",      "Voltage raw integers (DEFAULT: N)             ") { |v| adjV     =  !(v.match(/^[yt1]/i)) }
  opts.on("-t Y/N",  "--title Y/N",     "Print titles (DEFAULT: Y)                     ") { |v| outTitle = !!(v.match(/^[yt1]/i)) }
  opts.on("-s SEP",  "--separator SEP", "Separator (DEFAULT: comma)                    ") { |v| outSep   = v                      }
  opts.on("-p FILE", "--preamble FILE", "File with preamble data                       ") { |v| preFileN = v                      }
  opts.on("-o FILE", "--output FILE",   "Output file                                   ") { |v| outFileN = v                      }
  opts.separator("        A single dash may be used for STDOUT                         ")
  opts.separator("                                                                     ")
  opts.separator("I have only tested on the Siglent SDS2000X+ series, but it should    ")
  opts.separator("work on other Siglent scopes with the same data formats like the     ")
  opts.separator("SDS5000X, SDS6000 Pro, DS6000A, SHS800X, SHS1000X, & SDS2000X HD.    ")
  opts.separator("                                                                     ")
end
opts.parse!(ARGV)

if ( !(outFileN)) then
  if verbose >= 1 then
    STDERR.puts("\nERROR: Must provide an output file!\n")
    STDERR.puts(opts)
  end
  exit
end

if ( !(preFileN)) then
  if verbose >= 1 then
    STDERR.puts("\nERROR: Must provide a preamble file!\n")
    STDERR.puts(opts)
  end
  exit
end

outFileD = nil
if (outFileD == '-') then
  outFileD = STDOUT
else
  outFileD = open(outFileN, "wb");
end

dataFileNames = ARGV.clone;

if dataFileNames.empty? then
  if verbose >= 1 then
    STDERR.puts("\nERROR: Must provide at least one input!\n")
    STDERR.puts(opts)
  end
  exit
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Scope Data
code_per_div           = 30.0
hori_num               = 10.0
bitsPerSampleLow       = 8
bitsPerSampleHigh      = 16
time_base_enum         = [     2e-10,5e-10,
                          1e-9, 2e-9, 5e-9,
                          1e-8, 2e-8, 5e-8,
                          1e-7, 2e-7, 5e-7,
                          1e-6, 2e-6, 5e-6,
                          1e-5, 2e-5, 5e-5,
                          1e-4, 2e-4, 5e-4,
                          1e-3, 2e-3, 5e-3,
                          1e-2, 2e-2, 5e-2,
                          1e-1, 2e-1, 5e-1,
                          1e+0, 2e+0, 5e+0,
                          1e+1, 2e+1, 5e+1,
                          1e+2, 2e+2, 5e+2,
                          1e+3]
probe_attenuation_enum = [1e-1, 2e-1, 5e-1,
                          1e+0, 2e+0, 5e+0,
                          1e+1, 2e+1, 5e+1,
                          1e+2, 2e+2, 5e+2,
                          1e+3, 2e+3, 5e+3,
                          1e+4,
                          "CUSTA",
                          "CUSTB",
                          "CUSTC",
                          "CUSTD"]
wave_source_enum       = ['C1', 'C2', 'C3', 'C4']
bandwidth_limit_enum   = ['OFF', '20M', '200M']
vert_coupling_enum     = ['DC', 'AC', 'GND']
comm_type_enum         = ['BYTE', 'WORD']
comm_order_enum        = ['LSB', 'MSB']
preamble_desc          = [['header',            'a11'],
                          ['descriptor_name',   'a16'], 
                          ['template_name',     'a16'],
                          ['comm_type',         'v'  ],
                          ['comm_order',        'v'  ],
                          ['wave_desc_length',  'V'  ], 
                          ['unk40-1',           'V'  ], ['unk40-2',  'V' ], ['unk40-3',  'V' ], ['unk40-4',  'V' ], ['unk40-5', 'V' ],
                          ['wave_array',        'V'  ],
                          ['unk64-1',           'V'  ], ['unk64-2',  'V' ], ['unk64-3',  'V' ],
                          ['instrument_name',   'a16'],
                          ['unk92',             'V'  ],
                          ['unk96',             'a16'], 
                          ['unk112',            'V'  ],
                          ['wave_array_count',  'V'  ], 
                          ['unk120-1',          'V'  ], ['unk120-2', 'V' ], ['unk120-3', 'V' ],
                          ['first_point',       'V'  ],
                          ['data_interval',     'V'  ],
                          ['unk140',            'V'  ],
                          ['read_frames',       'V'  ],
                          ['sum_frames',        'V'  ], 
                          ['unk152-1',          'v'  ], ['unk152-2', 'v' ],
                          ['vert_gain',         'e'  ],
                          ['vert_offset',       'e'  ],
                          ['code_per_div',      'e'  ],
                          ['unk168',            'e'  ],
                          ['adc_bit',           'v'  ],
                          ['frame_index',       'v'  ],
                          ['horz_interval',     'e'  ],
                          ['horz_offset',       'E'  ], 
                          ['unk188',            'E'  ], 
                          ['unk196',            'a48'],
                          ['unk244',            'a48'],
                          ['unk292',            'e'  ], 
                          ['unk296',            'a16'],
                          ['unk312',            'e'  ], 
                          ['unk316-1',          'v'  ], ['unk316-2', 'v' ], ['unk316-3', 'v' ], ['unk316-4', 'v' ], 
                          ['time_base',         'v'  ],
                          ['vert_coupling',     'v'  ],
                          ['probe_attenuation', 'e'  ],
                          ['fixed_vert_gain',   'v'  ],
                          ['bandwidth_limit',   'v'  ], 
                          ['unk336-1',          'e'  ], ['unk336-2', 'e' ],
                          ['wave_source',       'v'  ],
                          ['ending_LF',         'a1' ]]
preamble_unpack_code   = preamble_desc.transpose.last.join(' ')
used_preamble_keys     = ['vert_gain', 
                          'probe_attenuation', 
                          'vert_offset', 
                          'horz_interval', 
                          'time_base', 
                          'horz_offset', 
                          'comm_type']

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - Reading preamble data file")
end
preaRawData=File.read(preFileN, :encoding=>'binary')

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - Parse & extract preamble data")
end

preamble_data_array = preaRawData.unpack(preamble_unpack_code)
preamble_data_hash  = preamble_desc.transpose.first.zip(preamble_data_array).to_h

# Report on preamble data
if verbose >= 4 then  
  preamble_desc.each do |pname, ptype|
    if ((verbose >= 6) || (used_preamble_keys.member?(pname))) then
      STDERR.printf("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - %25s : %s\n", pname, preamble_data_hash[pname].inspect)
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Constants usefull to transform data
vdiv = preamble_data_hash['vert_gain'] * preamble_data_hash['probe_attenuation']
voff = preamble_data_hash['vert_offset'] * preamble_data_hash['probe_attenuation']
hint = preamble_data_hash['horz_interval']
hdiv = time_base_enum[preamble_data_hash['time_base']]
hoff = preamble_data_hash['horz_offset']

bitsPerSample = bitsPerSampleLow
if (preamble_data_hash['comm_type'] == 1) 
  bitsPerSample = bitsPerSampleHigh
end

# Sample extract & adjust
sampleMaxP1  = 2**bitsPerSample
sampleMax    = sampleMaxP1 - 1
sampleMin    = 0
sampleMiddle = sampleMaxP1 / 2 - 1

wave_unpack_code = 'a11, C*'
if (bitsPerSample > 8) then
  wave_unpack_code = 'a11, v*'
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
sampleCount = nil
vData = Array.new
dataFileNames.each do |curDataFileName|
  if verbose >= 3 then
    STDERR.puts("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - Reading waveform data: #{curDataFileName}")
  end
  File.open(curDataFileName, 'rb') do |curDataFileD|
    waveRawData = curDataFileD.read;
    
    if verbose >= 3 then
      STDERR.puts("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - Transforming Y data")
    end

    samples = waveRawData.unpack(wave_unpack_code)[1..-3]

    if sampleCount.nil? then
      sampleCount = samples.length
    else
      if (sampleCount != samples.length) then
        if verbose >= 1 then
          STDERR.puts("ERROR: File #{curDataFileName} has a diffrent number (#{samples.length}) of samples from previous file (#{sampleCount})!")
        end
        exit
      end
    end

    if(adjV) then
      vData.push(samples.map { |v| (v>sampleMiddle ? v-sampleMaxP1 : v)/code_per_div*vdiv-voff })
    else
      vData.push(samples.map { |v| (v>sampleMiddle ? v-sampleMaxP1 : v) })
    end
  end
end

tData = (0..(sampleCount-1)).map { |i| -hoff-(hdiv*hori_num/2)+i*hint; }

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - Printing Data")
end

if outTitle then
  if (vData.length == 1) then
    if outTime then
      outFileD.puts("t#{outSep}v")
    else
      outFileD.puts('v')
    end
  else
    if outTime then
      outFileD.puts(([ 't' ] + (1..(vData.length)).map { |i| "v#{i}"; }).join(outSep))
    else
      outFileD.puts(((1..(vData.length)).map { |i| "v#{i}"; }).join(outSep))
    end
  end
end
updateTime = Time.now.localtime
tData.each_with_index do |tVal, tIdx|
  if (verbose >= 5) then
    curTime = Time.now.localtime;
    if ((curTime - updateTime) > 5) then
      updateTime = curTime;
      STDERR.puts("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - #{(100.0*tIdx/sampleCount).to_i}% complete")
    end
  end
  outFileD.puts(([ tVal ] + vData.map { |x| x[tIdx] }).join(outSep))
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if verbose >= 3 then
  STDERR.puts("sdsRAW2CSV: #{Time.new.inspect.ljust(35, ' ')} - Finished")
end
