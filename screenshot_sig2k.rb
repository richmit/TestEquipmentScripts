#!/usr/bin/env -S ruby
# -*- Mode:ruby; Coding:us-ascii-unix; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      screenshot_sig2k.rb
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Pull a PNG screenshot from a Siglent SDS2000X+ series oscilloscope.@EOL
# @std       Ruby 3 mrSCPI
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
if (ARGV[0] && ARGV[0].match(/^-+h/)) then
  puts("This script will pull a PNG screenshot from a Siglent SDS2000X+ series oscilloscope.")
  puts("The screenshot file looks like DATESTAMP_SDS.png")
  exit
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
require ENV['PATH'].split(File::PATH_SEPARATOR).map {|x| File.join(x, 'mrSCPI.rb')}.find {|x| FileTest.exist?(x)}

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
imgFileName    = "#{Time.now.localtime.strftime('%Y%m%d%H%M%S')}_SDS.png"
theSPCIsession = SCPIsession.new(:url                     => '@sig2k',
                                 :read_timeout_next_byte  => 200,
                                 :read_timeout_first_byte => 2000,
                                 :read_retry_delay        => 1,
                                 :cmd                     => ":PRINt? PNG",
                                 :print_raw_result        => true,
                                 :out_file                => imgFileName
                                )
puts("screenshot_sig2k.rb: Screen image captured to: #{imgFileName}")
