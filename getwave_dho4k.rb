#!/usr/bin/env -S ruby
# -*- Mode:ruby; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      getwave_dho4k.rb
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Grab waveform data from Rigol DHO2000/DHO4000 series oscilloscopes.@EOL
# @std       Ruby_3
# @deps      mrSCPI ruby
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
require ENV['PATH'].split(File::PATH_SEPARATOR).map {|x| File.join(x, 'mrSCPI.rb')}.find {|x| FileTest.exist?(x)}

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
require 'optparse'
require 'optparse/time'

# Parse command line arguments
verbLvl  = 5
chanList = ['CHANnel1']
filePfx  = Time.now.localtime.strftime('%Y%m%d%H%M%S')
chanRe   = /CHAN[nelNEL]*[1-4]|MATH[1-4]/;
opts = OptionParser.new do |opts|
  opts.banner = "Usage: getwave_dho4k.rb <options>"
  opts.separator "                                                     "
  opts.separator "Options:                                             "
  opts.on("-h",       "--help",            "Show this message")        { puts opts; exit                }
  opts.on("-v NUM",   "--verbose NUM",     "Verbose level")            { |v| verbLvl = v.to_i;          }
  opts.separator "    Valid values:                                    "
  opts.separator "      - 1 ... Error messages                         "
  opts.separator "      - 5 ... Metadata (DEFAULT)                     "
  opts.on("-c CHANS", "--chan CHANS",      "Channel List")             { |v| chanList = v.scan(chanRe); }
  opts.separator "    Default: CHANnel1                                "
  opts.separator "    Valid channels: CHANnel1-4, MATH1-4              "
  opts.separator "    Invalid channels are ignored.                    "
  opts.on("-p NAME",  "--filePrefix NAME", "Output file name prefix")  { |v| filePfx = v;               }
  opts.separator "    Default: time/date                               "
  opts.separator "    File names: FPFX_CHAN_waveform.EXT               "
  opts.separator "      - FPFX ... The --filePrefix option             "
  opts.separator "      - CHAN ... Channel name                        "
  opts.separator "      - EXT .... Extension                           "
  opts.separator "          - .pre ... Waveform preamble data          "
  opts.separator "          - .dat ... Waveform raw data               "
  opts.separator "                                                     "
end
opts.parse!(ARGV)

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if chanList.empty? then
  if (verbLvl >= 1) then
    STDERR.puts("getwave_dho4k.rb: ERROR: Channel list empty (probably a bad -c argument value)")
  end
  exit
end

if (verbLvl >= 5) then
  STDERR.puts("getwave_dho4k.rb: INFO: verbLvl ..... #{verbLvl.inspect   }")
  STDERR.puts("getwave_dho4k.rb: INFO: chanList .... #{chanList.inspect  }")
  STDERR.puts("getwave_dho4k.rb: INFO: filePfx ..... #{filePfx.inspect   }")
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
scpiSession = SCPIsession.new(:url   => '@dho4k',
                              :echo  => false)
scpiSession.command(':STOP', 
                    :result_type => nil)

scpiSession.command(":ACQuire:MDEPth?", 
                    :result_type => :float)

aqPoints = scpiSession.variable('ANS')
if (verbLvl >= 5) then
  STDERR.puts("getwave_dho4k.rb: INFO: aqPoints .... #{aqPoints.inspect}")
  aqPoints = aqPoints.to_i
  STDERR.puts("getwave_dho4k.rb: INFO: aqPointsI ... #{aqPoints.inspect}")
end

scpiSession.command(":WAVeform:MODE RAW; :WAVeform:FORMat WORD; :WAVeform:POINts #{aqPoints}; :WAVeform:STARt 1",
                    :result_type => nil)

scpiSession.set(:print_raw_result        => true,
                :delay_before_first_read => 50,
                :read_retry_delay        => 10,
                :read_timeout_next_byte  => 100,
                :read_timeout_first_byte => 2000)
chanList.each do |curChan|
  if (verbLvl >= 5) then
    puts("Downloading: #{curChan}")
  end
  scpiSession.command(":WAVeform:SOURce #{curChan}", 
                      :result_type => nil)
  scpiSession.command(':WAVeform:PREamble?', 
                      :result_type => :string,
                      :out_file    => "#{filePfx}_#{curChan}_waveform.pre")
  scpiSession.command(':WAVeform:DATA?',     
                      :result_type => :string,
                      :out_file    => "#{filePfx}_#{curChan}_waveform.dat")
end
