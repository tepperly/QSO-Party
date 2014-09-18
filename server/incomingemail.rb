#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP configuration information
# Tom Epperly NS6T
# ns6t@arrl.net
#
#
require 'net/imap'
require 'mail'
require 'tempfile'
require_relative 'email'
require_relative 'config'
require_relative 'charset'
require_relative 'patchlog'
require_relative 'database'
require_relative 'loghtml'
require_relative 'logscan'
require_relative 'logops'

def htmlToPlain(str, mimeType)
  if mimeType and (mimeType =~ /^text\/html/i)
    file = Tempfile.new('cqp_html_txt', :encoding => Encoding::UTF_8)
    file.write(str)
    file.close
    IO.popen("w3m -dump -T \"text/html\" -I UTF-8 -O UTF-8 #{file.path}", :encoding => Encoding::UTF_8) { |input|
      str = input.read
    }
    print "Converted to plain text: #{str}\n"
  end
  str
end

def fixCharset(content, mimeType, charset)
  if Encoding::ASCII_8BIT == content.encoding
    if charset and mimeType and (mimeType =~ /^text\//i)
      begin
        return htmlToPlain(content.clone.force_encoding(charset), mimeType)
      rescue => e
        $stderr.write("Exception during fixCharset: #{e.class.to_s} #{e.message}\n")
        #ignore exception
      end
    end
    encoding = guessEncoding(content)
    begin
      return htmlToPlain(content.clone.force_encoding(encoding), mimeType)
    rescue => e
      $stderr.write("Exception during fixCharset (2): #{e.class.to_s} #{e.message}\n")
    end
    content = htmlToPlain(convertToEncoding(content, Encoding::US_ASCII), # force encoding
                          mimeType)
  end
  content
end

LOGREGEX=/^(START-OF-LOG|END-OF-LOG|QSO):/i

def checkIfLog(content)
  LOGREGEX.match(content)
end

def processEmailLog(rawContent, fixedContent, filename, subject, sender, headers, db, logCheck)
  timestamp = Time.new.utc
  callsign = getCallsign(fixedContent)
  asciiContent = convertToEncoding(fixedContent, Encoding::US_ASCII)
  logID = db.getID
  log = logCheck.checkLogStr(filename, logID, asciiContent)
  if log
    db.addQSOCount(logID, log.maxqso, log.validqso)
    if log.callsign and log.callsign != "UNKNOWN"
      callsign = log.callsign
    end
  end
  if not callsign
    callsign = "UNKNOWN"
  end
  untouchedFilename = saveLog(rawContent, callsign, "virgin", timestamp)
  asciiFilename = saveLog(asciiContent, callsign, "ascii", timestamp, Encoding::US_ASCII)
  saveLog(fixedContent.encoding.to_s, callsign, "encoding", timestamp, Encoding::US_ASCII)
  if untouchedFilename and asciiFilename
    db.addLog(logID, callsign, filename, untouchedFilename, asciiFilename,
              fixedContent.encoding.to_s,
              timestamp, Digest::SHA1.hexdigest(rawContent).to_s,
              "email")
    print "Id: #{logID}\nCallsign: #{callsign}\nEmail: #{sender}\nOp class: #{log.powerStr}\n"
    db.addExtra(logID, callsign, sender, log.calcOpClass, log.powerStr,
                log.filterQTH[0].to_s, "", "",
                log.county?, log.youth?, log.mobile?, log.female?, log.school?,
                log.newcontester?, "email")
    attrib = makeAttributes(logID, callsign, sender, sender, log.filterQTH[0].to_s,
                            "", "", log.county?, log.youth?, log.mobile?,
                            log.female?, log.school?, log.newcontester?)
    patchedContent = patchLog(asciiContent, attrib) # add X-CQP lines
    open(asciiFilename.gsub(/\.ascii$/, ".log"),
         File::Constants::CREAT | File::Constants::EXCL | 
         File::Constants::WRONLY,
         :encoding => "US-ASCII") { |lout|
      lout.write(patchedContent)
    }
    outE = OutgoingEmail.new
    html = logHtml(log, db.getEntry(logID))
    outE.sendEmailAlt(sender, "CQP 2014 Log Confirmation", htmlToPlain(html, "text/html"), html)
    return true
  end
  false
end

def processPartOrAttachment(content, filename, mimeType, charset, subject, sender, headers, db, logCheck)
  num = 0
  fixedContent = fixCharset(content, mimeType, charset)
  if checkIfLog(fixedContent)
    if processEmailLog(content, fixedContent, filename, subject, sender, headers, db, logCheck)
      num = 1
    end
  end
  num
end

def checkMail(mail, subject, sender, headers, db, logCheck)
  numlogs = 0
  if mail.multipart?
    hasAlternatives = (mail.content_type.to_s =~ /^multipart\/alternative/)
    # check attachments first
    mail.attachments.each { |attach|
      numlogs = numlogs + 
         processPartOrAttachment(attach.body.decoded, attach.filename,
                                 attach.mime_type, attach.charset,
                                 subject, sender, headers, db, logCheck)
    }
    mail.parts.each { |part|
      if not part.attachment?   # presumably all attachments are already done
        if (not hasAlternatives) or (part.content_type =~ /^text\/plain/)
          numlogs = numlogs + checkMail(part, subject, sender, headers, db, logCheck)
        end
      end
    }
  else                          # not multipart
    numlogs = numlogs + 
      processPartOrAttachment(mail.body.decoded, 
                              (mail.filename ? mail.filename : ""),
                              mail.mime_type, mail.charset,
                              subject, sender, headers, db, logCheck)
  end
  numlogs
end

def getReturnEmail(mail)
  mail.from[0]
end

db = LogDatabase.new
logCheck = CheckLog.new
imap = Net::IMAP.new(CQPConfig::INCOMING_IMAP_HOST, CQPConfig::INCOMING_IMAP_PORT, usessl = true, certs = nil, verify = false)
imap.login(CQPConfig::INCOMING_IMAP_USER, CQPConfig::INCOMING_IMAP_PASSWORD)

imap.select(CQPConfig::INCOMING_IMAP_FOLDER)

msgs = imap.uid_search(["ALL"])

msgs.each { |uid|
  _body = imap.uid_fetch(uid, "RFC822")[0].attr["RFC822"]

  print "Message #{uid} " + _body.encoding.to_s + "\n"
  open("/tmp/mailtests/file#{uid}.raw", "wb") { |out|
    out.write(_body)
  }

  mail = Mail.new(_body)
  numlogs = checkMail(mail, mail.subject, getReturnEmail(mail), mail.header, db, logCheck)
  if numlogs > 0
    print "Mail message #{uid} had #{numlogs} log(s)\n"
  end
  if mail.multipart?
    print "Mail is multipart\n"
    print mail.parts.length.to_s + " parts\n"
    print "Overall content-type: " + mail.content_type.to_s + "\n"
    mail.attachments.each { |attach|
      print "Mime type: " + attach.mime_type.to_s + "\n"
      print "Charset: " + attach.charset.to_s + "\n"
      
    }
    mail.parts.each { |part|
      print part.content_type + "\n"
      print "Type params: " + part.content_type_parameters.to_s + "\n"
      print "Text encoding: " + part.body.decoded.encoding.to_s + "\n"
      print part.attachment? ? "Is attachment\n" : "Isn't attachment\n"
      print "Filename: " + part.filename.to_s + "\n"
    }
  else
    
    print "Mail is single part\n"
    print "Content type: " + mail.content_type.to_s + "\n"
    print "Type params: " + mail.content_type_parameters.to_s + "\n"
    print "Bodying encoding: " + mail.body.decoded.encoding.to_s + "\n"
  end
  print "\n\n"
#  print _body
}
