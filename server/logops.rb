#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# Basic log operations
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

LOGDIR="/usr/local/cqplogs"
MAXTRIES=20
CALLSIGN = /^\s*callsign\s*:\s*(\S+)\s*$/i

def getCallsign(str)
  match = CALLSIGN.match(str)
  if match
    return match[1].strip.upcase
  end
  nil
end

def logFilename(prefix, suffix, time, numtry)
  if numtry > 0
    extraletter = ('A'.ord + numtry).chr
  else
    extraletter = ""
  end
  LOGDIR + "/" + prefix + time.strftime("-%Y%m%d-%H%M%S-%L") + extraletter + "." + suffix
end

def saveLog(content, fileprefix, filesuffix, time, encoding=nil)
  fileprefix = fileprefix.gsub(/[^A-Za-z0-9]/, "_")
  filename = nil
  converted = convertToEncoding(content, encoding)
  encoding = converted.encoding
  tries = 0
  success = false
  while tries < MAXTRIES and not success
    begin
      filename = logFilename(fileprefix, filesuffix, time, tries)
      open(filename,
           File::Constants::CREAT | File::Constants::EXCL | 
           File::Constants::WRONLY,
           :encoding => encoding) { |io|
        io.write(converted)
        success = true
      }
    rescue
      tries = tries + 1
      filename = nil
    end
  end
  filename
end
