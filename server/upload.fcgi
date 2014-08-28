#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP upload script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#
require 'fcgi'
require 'digest/sha1'
require 'json'
require_relative 'charset'
require_relative 'database'
require_relative 'logscan'
require_relative 'patchlog'

CALLSIGN = /^\s*callsign\s*:\s*(\S+)\s*$/i
LOGDIR="/usr/local/cqplogs"
MAXTRIES=20

# $outfile = open("/tmp/foo.txt", "a")
# $outfile.write("Starting\n")

def getCallsign(str)
  match = CALLSIGN.match(str)
  if match
    return match[1].strip.upcase
#  else
#    $outfile.write("No callsign\n")
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
  filename = nil
  if (not encoding) or (content.encoding == encoding)
    converted = content
    encoding  = content.encoding
  else
    converted = content.encode(encoding, :invalid => :replace, 
                               :undef => :replace)
  end
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
#      $outfile.write("Failed to write " + filename + "\n")
      tries = tries + 1
      filename = nil
    end
  end
  filename
end

def hasRequired(request)
  required = [ "email", "confirm", "phone", "logID", "comments" ]
  # "expedition", "youth", "female", "school", "new", "logID" ]
  required.each { |key|
    if not request.has_key?(key)
      return false
    end
  }
  true
end

def checkBox(req, key)
  req.has_key?(key) ? 1 : 0
end

def guessEmail(str)
  if (str =~ /^email:\s*(.*)$/i)
    result = $1.strip
    if result.length > 0
      return result
    end
  end
  nil
end


db = LogDatabase.new
FCGI.each_cgi { |request|
  timestamp = Time.new.utc
  logID=nil
  jsonout = { }
  if request.multipart?
#    $outfile.write("Received multipart request\n")
    request.params.each { |key, value| 
#      $outfile.write("cgi[" + key.to_s + "] = '" + value.to_s + "' of type " +
#                     value.class.to_s + "\n")
    }
    if request.has_key?("cabrillofile")
      jsonout["files"] = [ ]
      fileent = { }
      val = request["cabrillofile"]
#      $outfile.write("local_path=" + val.local_path.to_s + "\n")
#      $outfile.write("original_filename=" + val.original_filename.to_s + "\n")
      fileent["name"] = val.original_filename.to_s
#      $outfile.write("content_type=" + val.content_type.to_s + "\n")
      content = val.read
      probableEncoding = guessEncoding(content)
#     $outfile.write("probable = " + probableEncoding.to_s + "\n")
      begin
        encodedContent = content.clone.force_encoding(probableEncoding)
#        $outfile.write("encoded type = " + encodedContent.encoding.to_s + "\n")
        callsign = getCallsign(encodedContent)
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
#        $outfile.write("Exception")
        callsign = getCallsign(content)
        encodedContent = content
      end
      if not callsign
        callsign = "UNKNOWN"
      end
      untouchedFilename = saveLog(content, callsign, "virgin", timestamp)
      asciiFilename = saveLog(encodedContent, callsign, "ascii", timestamp, Encoding::US_ASCII)
      saveLog(encodedContent.encoding.to_s, callsign, "encoding", timestamp,
              Encoding::US_ASCII)
      if untouchedFilename and asciiFilename
        logID = db.addLog(callsign, untouchedFilename, asciiFilename,
                          encodedContent.encoding.to_s,
                          timestamp, Digest::SHA1.hexdigest(content).to_s)
      end
      
#      $outfile.write("content length=" + content.length.to_s + "\n")
#      $outfile.write("content encoding=" + content.encoding.to_s + "\n")
#      $outfile.write("content SHA1=" + Digest::SHA1.hexdigest(content).to_s + "\n" )
      if logID
        fileent["id"]=logID.to_i
      end
      jsonout["files"].push(fileent)
      jsonout["callsign"] = callsign
      email = guessEmail(encodedContent)
      if email
        jsonout["email"] = email
      end
    end
  else
#    $outfile.write("Received non-multipart request\n")
    request.params.each { |key, value| 
#      $outfile.write("cgi[" + key.to_s + "] = '" + value.to_s + "' of type " +
#                     value.class.to_s + "\n")
    }
    if request.has_key?("cabcontent")
      jsonout["files"] = [ ]
      fileent = { }
      content = request["cabcontent"]
#      $outfile.write("content encoding=" + content.encoding.to_s + "\n")
      encodedContent = content
      probableEncoding = Encoding::UTF_8
      callsign = getCallsign(content)
      if not callsign
        callsign="UNKNOWN"
      end
      untouchedFilename = saveLog(content, callsign, "virgin", timestamp)
      asciiFilename = saveLog(encodedContent, callsign, "ascii", timestamp, Encoding::US_ASCII)
      saveLog(encodedContent.encoding.to_s, callsign, "encoding", timestamp,
              Encoding::US_ASCII)
      if untouchedFilename and asciiFilename
        logID = db.addLog(callsign, untouchedFilename, asciiFilename,
                          encodedContent.encoding.to_s,
                          timestamp, Digest::SHA1.hexdigest(content.clone.force_encoding(Encoding::ASCII_8BIT)).to_s)
      end
      if logID
        fileent["id"] = logID.to_i
      end
      jsonout["files"].push(fileent)
      jsonout["callsign"] = callsign
      email = guessEmail(encodedContent)
      if email
        jsonout["email"] = email
      end
    end
    if hasRequired(request)
      if not logID
        logID = request["logID"].to_i
      end
      db.addExtra(logID, request["callsign"],
                  request["email"], request["phone"],
                  request["comments"],
                  checkBox(request, "expedition"), checkBox(request, "youth"),
                  checkBox(request, "mobile"), checkBox(request, "female"),
                  checkBox(request, "school"), checkBox(request, "new"))
      asciiFile = db.getASCIIFile(logID)
      if asciiFile
        attrib = makeAttributes(logID, request["callsign"],
                                request["email"], request["confirm"], request["phone"],
                                request["comments"],
                                checkBox(request, "expedition"), checkBox(request, "youth"),
                                checkBox(request, "mobile"), checkBox(request, "female"),
                                checkBox(request, "school"), checkBox(request, "new"))
        open(asciiFile,File::Constants::RDONLY,
             :encoding => "US-ASCII") { |io|
          content = io.read()
          content = patchLog(content, attrib) # add X-CQP lines
          open(asciiFile.gsub(/\.ascii$/, ".log"), 
               File::Constants::CREAT | File::Constants::EXCL | 
               File::Constants::WRONLY,
               :encoding => "US-ASCII") { |lout|
            lout.write(content)
          }
        }
      end
#    else
#      $outfile.write("Missing some of required\n")
    end
  end
  request.out("text/javascript") { jsonout.to_json }
#  $outfile.flush
}
