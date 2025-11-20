#!/usr/bin/env -S ruby
# -*- Mode:ruby; Coding:us-ascii; fill-column:158 -*-
#########################################################################################################################################################.H.S.##
##
# @file      screenshot_tek3k.rb
# @author    Mitch Richling http://www.mitchr.me/
# @brief     Pull a PNG screenshot from a Tektronix TDS3000 series oscilloscope.@EOL
# @std       Ruby_3 mrSCPI
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
  STDERR.puts("                                                                                    ")
  STDERR.puts("Pull a PNG screenshot from a Tektronix TDS3000B series oscilloscope.                ")
  STDERR.puts("                                                                                    ")
  STDERR.puts("The screenshot is pulled via the instrument's web interface, and placed in a file   ")
  STDERR.puts("with a name like DATESTAMP_TDS3052B.png.  The DATESTAMP component uses the time     ")
  STDERR.puts("format string %Y%m%d%H%M%S.                                                         ")          
  STDERR.puts("                                                                                    ")
  exit
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
require ENV['PATH'].split(File::PATH_SEPARATOR).map {|x| File.join(x, 'mrSCPI.rb')}.find {|x| FileTest.exist?(x)}

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
require 'net/http'

imgData = Net::HTTP.get(URI.parse(SCPIrcFile.instance.lookupURLnickname('@tds3052w') + '/Image.png'))
if imgData then
  imgFileName = Time.now.localtime.strftime('%Y%m%d%H%M%S') + "_TDS3052B.png"
  open(imgFileName, "wb") do |ofile|
    ofile.write(imgData)
  end
  puts("screenshot_tek3k.rb: Screen image captured to: #{imgFileName}")
else
  puts("screenshot_tek3k.rb: Unable to capture screen!")
end
