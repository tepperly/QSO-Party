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
require_relative 'email'
require_relative 'logscan'
require_relative 'loghtml'
require_relative 'logops'

def hasRequired(request)
  required = [ "callsign", "email", "confirm", "phone", "logID", "comments", "opclass", "power", "sentQTH" ]
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

def getClub(name, altname)
  if name and (not ["OTHER", "NONE"].include?(name)) and (not name.strip.empty?)
    return name
  end
  if altname and not altname.strip.empty?
    return altname
  end
  return nil
end

def contentsMatch(content, filename)
  begin
    open(filename, File::Constants::RDONLY, :encoding => "US-ASCII") { |inf|
      fileContent = inf.read()
      return content == fileContent
    }
  rescue
    return false
  end
  return false
end

def handleRequest(request, db, logCheck)
  timestamp = Time.new.utc
  logID=nil
  source = nil
  jsonout = { }
  if request.multipart?
    source = "form1"
    if request.has_key?("cabrillofile")
      jsonout["files"] = [ ]
      fileent = { }
      val = request["cabrillofile"]
      fileent["name"] = val.original_filename.to_s
      content = val.read
      probableEncoding = guessEncoding(content)
      begin
        encodedContent = content.clone.force_encoding(probableEncoding)
        callsign = getCallsign(encodedContent)
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
        callsign = getCallsign(content)
        encodedContent = content
      end
      asciiContent = convertToEncoding(content, Encoding::US_ASCII)
      logID = db.getID
      log = logCheck.checkLogStr(fileent["name"], logID, asciiContent)
      if log 
        db.addWorked(logID, log.tally)
        db.addQSOCount(logID, log.maxqso, log.validqso)
        if log.callsign and log.callsign != "UNKNOWN"
          callsign = log.callsign
        end
      end
      if not callsign
        callsign = "UNKNOWN"
      end
      untouchedFilename = saveLog(content, callsign, "virgin", timestamp)
      asciiFilename = saveLog(asciiContent, callsign, "ascii", timestamp, Encoding::US_ASCII)
      saveLog(encodedContent.encoding.to_s, callsign, "encoding", timestamp,
              Encoding::US_ASCII)
      if untouchedFilename and asciiFilename
        db.addLog(logID, callsign, fileent["name"], untouchedFilename, asciiFilename,
                          encodedContent.encoding.to_s,
                          timestamp, Digest::SHA1.hexdigest(content).to_s,
                  source)
      end

      if log
        jsonout = log.to_json
      else
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
    end
  else
    if request.has_key?("source")
      source = request["source"]
    end
    if request.has_key?("cabcontent")
      jsonout["files"] = [ ]
      fileent = { }
      content = request["cabcontent"]
      encodedContent = content
      callsign = getCallsign(content)
      asciiContent = convertToEncoding(content, Encoding::US_ASCII)
      logID = db.getID
      log = logCheck.checkLogStr("", logID, asciiContent)
      if log 
        db.addWorked(logID, log.tally)
        if log.maxqso and log.validqso
          db.addQSOCount(logID, log.maxqso, log.validqso)
        end
        if log.callsign and log.callsign != "UNKNOWN"
          callsign = log.callsign
        end
      end
      if not callsign
        callsign = "UNKNOWN"
      end
      untouchedFilename = saveLog(content, callsign, "virgin", timestamp)
      asciiFilename = saveLog(asciiContent, callsign, "ascii", timestamp, Encoding::US_ASCII)
      saveLog(encodedContent.encoding.to_s, callsign, "encoding", timestamp,
              Encoding::US_ASCII)
      if untouchedFilename and asciiFilename
        db.addLog(logID, callsign, "", untouchedFilename, asciiFilename,
                  encodedContent.encoding.to_s,
                  timestamp, Digest::SHA1.hexdigest(content.clone.force_encoding(Encoding::ASCII_8BIT)).to_s,
                  source)
      end
      if log
        jsonout = log.to_json
      else
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
    end
    if hasRequired(request)
      if not logID
        logID = request["logID"].to_i
      end
      clubName = 
      db.addExtra(logID, request["callsign"],
                  request["email"], 
                  request["opclass"],
                  request["power"],
                  request["sentQTH"],
                  request["phone"],
                  request["comments"],
                  checkBox(request, "expedition"), checkBox(request, "youth"),
                  checkBox(request, "mobile"), checkBox(request, "female"),
                  checkBox(request, "school"), checkBox(request, "new"), 
                  source, nil, 
                  getClub(request["clubname"], request["otherclubname"]), 
                  request["clubsize"])
      asciiFile = db.getASCIIFile(logID)
      if asciiFile
        attrib = makeAttributes(logID, request["callsign"],
                                request["email"], request["confirm"], 
                                request["sentqth"],
                                request["phone"],
                                request["comments"],
                                checkBox(request, "expedition"), checkBox(request, "youth"),
                                checkBox(request, "mobile"), checkBox(request, "female"),
                                checkBox(request, "school"), checkBox(request, "new"),
                                request['clubname'],
                                request['otherclubname'],
                                request['clubsize'],
                                request['opclass'],
                                request['power'])
        open(asciiFile,File::Constants::RDONLY,
             :encoding => "US-ASCII") { |io|
          content = io.read()
          content = patchLog(content, attrib) # add X-CQP lines
          iteration=0
          notWritten = true
          while (notWritten)
            if (iteration > 0)
              suffix=("_" + iteration.to_s)
            else
              suffix=""
            end
            logFilename = asciiFile.gsub(/\.ascii$/, suffix + ".log")
            begin
              open(logFilename, 
                   File::Constants::CREAT | File::Constants::EXCL | 
                   File::Constants::WRONLY,
                   :encoding => "US-ASCII") { |lout|
                lout.write(content)
              }
              notWritten = false
            rescue
              if (contentsMatch(content, logFilename))
                notWritten = false
              else
                iteration = iteration + 1
              end
            end
          end
        }
      end
    end
  end
  emailConfirmation(db, logID)
  content = nil
  encodedConent = nil
  if source !~ /form[34]/
    request.out("text/javascript") { jsonout.to_json }
  else
    request.out("text/html") { logHtml(log, db.getEntry(logID)) }
  end
end


db = LogDatabase.new
logCheck = CheckLog.new
FCGI.each_cgi { |request|
  begin
    handleRequest(request, db, logCheck)
  rescue => e
    $stderr.write(e.message + "\n")
    $stderr.write(e.backtrace.join("\n"))
    $stderr.flush()
    db.addException(e)
    raise
  end
}
