#!/usr/bin/env -S ruby
# -*- Mode:ruby; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      getwave_sig2k.rb
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Grab waveform data from Siglent SDS2000X+ series oscilloscopes.@EOL
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
maxChunkSize = 10000000
verbLvl      = 9
firstFrame   = 1
endFrame     = nil
stepFrame    = 1
chanList     = ['C1']
filePfx      = Time.now.localtime.strftime('%Y%m%d%H%M%S')
chunkSize    = maxChunkSize
chanRe       = /C[1-4]|F[12]|D0[1-9]|D1[0-5]/;
opts = OptionParser.new do |opts|
  opts.banner = "Usage: getwave_sig2k.rb <options>"
  opts.separator "                                                     "
  opts.separator "Options:                                             "
  opts.on("-h",       "--help",            "Show this message")        { puts opts; exit                }
  opts.on("-v NUM",   "--verbose NUM",     "Verbose level")            { |v| verbLvl = v.to_i;          }
  opts.separator "    Valid values:                                    "
  opts.separator "      - 1 ... Error messages                         "
  opts.separator "      - 5 ... Metadata                               "
  opts.separator "      - 9 ... Progress information (Default)         "
  opts.on("-f NUM",   "--firstFrame NUM",  "Start frame to download")  { |v| firstFrame = v.to_i;       }
  opts.separator "    Default: 1                                       "
  opts.on("-e NUM",   "--endFrame NUM",    "Last frame to download")   { |v| endFrame = v.to_i;         }
  opts.separator "    Default: The value of the -s argument            "
  opts.on("-s NUM",   "--stepFrame NUM",   "Skip N frames")            { |v| stepFrame = v.to_i;        }
  opts.separator "    Default: 1                                       "
  opts.on("-x NUM",   "--xferSize NUM",    "Max points per download")  { |v| chunkSize = v.to_i;        }
  opts.separator "    Default: 10000000                                "
  opts.on("-c CHANS", "--chan CHANS",      "Channel List")             { |v| chanList = v.scan(chanRe); }
  opts.separator "    Default: C1                                      "
  opts.separator "    Valid channels: C1-C4, F1-2, D0-15               "
  opts.separator "    Invalid channels are ignored.                    "
  opts.on("-p NAME",  "--filePrefix NAME", "Output file name prefix")  { |v| filePfx = v;               }
  opts.separator "    Default: time/date                               "
  opts.separator "    File names: FPFX_CHAN_FRAME_waveform.EXT         "
  opts.separator "      - FPFX ... The --filePrefix option             "
  opts.separator "      - CHAN ... Channel name                        "
  opts.separator "      - FRAME .. Seven digit frame number            "
  opts.separator "      - EXT .... Extension                           "
  opts.separator "          - .pre ... Waveform preamble data          "
  opts.separator "          - .dat ... Waveform raw data               "
  opts.separator "              The leading 11 characters are X's if   "
  opts.separator "              the file results from concatenating    "
  opts.separator "              multiple :WAVeform:DATA? calls.        "
  opts.separator "                                                     "
  opts.separator " Note: Unlike my other getwave_* scripts, this one   "
  opts.separator "       doesn't automatically produce a .csv file     "
  opts.separator "       or plot the results.                          "
end
opts.parse!(ARGV)

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# If endFrame was not provided, then set it to firstFrame
if endFrame.nil? then
  endFrame = firstFrame
end

if endFrame < firstFrame then
  if (verbLvl >= 1) then
    STDERR.puts("getwave_sig2k.rb: ERROR: --firstFrame (#{firstFrame}) can't be greater than --endFrame (#{endFrame})!")
  end
  exit
end

if firstFrame < 1 then
  if (verbLvl >= 1) then
    STDERR.puts("getwave_sig2k.rb: ERROR: --firstFrame (#{firstFrame}) must be positive!")
  end
  exit
end

if stepFrame < 1 then
  if (verbLvl >= 1) then
    STDERR.puts("getwave_sig2k.rb: ERROR: --stepFrame (#{stepFrame}) must be positive!")
  end
  exit
end

if chanList.empty? then
  if (verbLvl >= 1) then
    STDERR.puts("getwave_sig2k.rb: ERROR: Channel list empty (probably a bad -c argument value)")
  end
  exit
end

if (chunkSize > maxChunkSize) then
  if (verbLvl >= 1) then
    STDERR.puts("getwave_sig2k.rb: ERROR: -x can't be larger than #{maxChunkSize}!")
  end
  exit
end

if (verbLvl >= 5) then
  STDERR.puts("getwave_sig2k.rb: INFO: verbLvl ..... #{verbLvl.inspect   }")
  STDERR.puts("getwave_sig2k.rb: INFO: firstFrame .. #{firstFrame.inspect}")
  STDERR.puts("getwave_sig2k.rb: INFO: endFrame .... #{endFrame.inspect  }")
  STDERR.puts("getwave_sig2k.rb: INFO: stepFrame ... #{stepFrame.inspect }")
  STDERR.puts("getwave_sig2k.rb: INFO: chunkSize ... #{chunkSize.inspect }")
  STDERR.puts("getwave_sig2k.rb: INFO: chanList .... #{chanList.inspect  }")
  STDERR.puts("getwave_sig2k.rb: INFO: filePfx ..... #{filePfx.inspect   }")
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
scpiSession = SCPIsession.new(:url                 => '@sig2k',
                              :echo                => false)
scpiSession.command(':HISTORy ON', 
                    :result_type => nil)
scpiSession.command(":WAVeform:POINt #{chunkSize}; :WAVeform:STARt 0; :WAVeform:INTerval 1", 
                    :result_type => nil)
scpiSession.command(":ACQuire:POINts?", 
                    :result_type => :float)

aqPoints = scpiSession.variable('ANS')
if (verbLvl >= 5) then
  STDERR.puts("getwave_sig2k.rb: INFO: aqPoints .... #{aqPoints.inspect}")
end

scpiSession.set(:print_raw_result        => true,
                :delay_before_first_read => 50,
                :read_retry_delay        => 10,
                :read_timeout_next_byte  => 100,
                :read_timeout_first_byte => 2000)
chanList.each do |curChan|
  scpiSession.command(':WAVeform:PREamble?', 
                      :result_type => :string,
                      :out_file    => "#{filePfx}_#{curChan}_XXXXXXX_waveform.pre")
  scpiSession.command(":WAVeform:SOURce #{curChan}", 
                      :result_type => nil)
  firstFrame.step(endFrame, stepFrame) do |curFrame|
    scpiSession.command(":HISTORy:FRAMe #{curFrame}", 
                        :result_type => nil)
    numChunks = (1.0 * aqPoints / chunkSize).ceil
    waveDat = "XXXXXXXXXXX";
    1.upto(numChunks) do |curChunk|
      if (verbLvl >= 9) then
        puts("Downloading:    CHAN: #{curChan}    FRAME: #{'%07d' % curFrame}    CHUNK: #{'%02d' % curChunk} of #{'%02d' % numChunks}")
      end
      scpiSession.command(":WAVeform:STARt #{chunkSize*(curChunk-1)}", 
                          :result_type => nil)
      scpiSession.command(':WAVeform:DATA?',     
                          :result_type       => :string,
                          :print_raw_result  => false)
      waveDat += scpiSession.result(:type => :raw_str)[11..-3]
    end
    waveDat += "\n\n";
    File.open("#{filePfx}_#{curChan}_#{'%07d' % curFrame}_waveform.dat", 'wb') do |oCFD|
      oCFD.write(waveDat)
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Testing methodology:
#
# ###################################################################################################################
# # Test that we get consistant data with diffrent chunk sizes
# #
# # In a shell
# rm test1* test2*
# # Done with: chunkSize = 1000000
# ./getwave_sig2k.rb -c C1 -e 1 -s 1 -p test1
# # Done with: chunkSize = 10000000
# ./getwave_sig2k.rb -c C1 -e 1 -s 1 -p test2
# ../sdsRAW2CSV.rb -p test2_C1_*.pre -o test2.csv test2_C1*.dat
# ../sdsRAW2CSV.rb -p test1_C1_*.pre -o test1.csv test1_C1*.dat
#
# # In octave or matlab graph the diffrence between the two as well as each waveform.  Should get a flat line at zero for the diffrnece.  Shoudl get what
# # looks like one curve for the weveform, and it shoudl look like what was on the scope screen.
# d1 = dlmread("test1.csv", ",", 1, 0);
# d2 = dlmread("test1.csv", ",", 1, 0);
# len = min(length(d1(:,1)), length(d2(:,1)));
# dif = d1(1:len,2) - d2(1:len,2);
# figure()
# hold on
# plot(dif)
# plot(d1(:,2))
# plot(d2(:,2))
#
# ###################################################################################################################
# # Test captureing a multiple frames, and ploting them all at once.
#
# # In a shell.  Probably want to set the scope so only a few points are in each frame (<1000)
# rm test5*
# ./getwave_sig2k.rb -c C1 -e 500 -s 1 -p test3
# ../sdsRAW2CSV.rb -p test3_C1_*.pre -o test3.csv test3_C1*.dat
#
# # In octave or matlab graph the 
# figure()
# hold on
# for i = 2:size(d3, 2); plot(d3(:,1), d3(:,i));  end
