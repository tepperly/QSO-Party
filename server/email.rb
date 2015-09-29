#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP email
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

require 'base64'
require 'net/smtp'
require_relative 'config'

class OutgoingEmail
  def initialize
    @smtp = Net::SMTP.new(CQPConfig::EMAIL_SERVER, CQPConfig::EMAIL_PORT)
    if CQPConfig::EMAIL_USE_TLS
      @smtp.enable_starttls
    end
    if CQPConfig::EMAIL_LOGIN_REQUIRED
      @smtp.start(CQPConfig::EMAIL_DOMAIN, CQPConfig::EMAIL_ADDRESS, CQPConfig::EMAIL_PASSWORD, :login)
    else
      @smtp.start(CQPConfig::EMAIL_DOMAIN)
    end
  end
  
  def sendEmail(recipient, subject, body, attachments=[])
    header = "From: #{CQPConfig::EMAIL_NAME} <#{CQPConfig::EMAIL_ADDRESS}>\nTo: #{recipient}\nSubject: #{subject}\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\n"
    boundary = ""
    if attachments.length > 0
      boundary = "mime_part_boundary_" + ("%08X" % rand(0xffffffff)) + "_" + ("%08X" % rand(0xffffffff))
      header = header + "Content-Type: multipart/mixed;\n    boundary=#{boundary}\n--#{boundary}\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n"
      attachstr = "--#{boundary}\n"
      attachments.each { |file|
        attachstr = attachstr + "Content-Type: #{file['mime']}\nContent-Transfer-Encoding: base64\nContent-Disposition: attachment; filename=\"#{file['filename']}\"\n\n#{Base64.encode64(file['content'])}\n--#{boundary}\n"
      }
      attachstr = attachstr + "--"
    else 
      header = header + "Content-Type: text/plain; charset=utf-8\n"
      attachstr = ""
    end
    body = body.encode(Encoding::UTF_8)
    @smtp.send_message(header + body + attachstr, CQPConfig::EMAIL_ADDRESS, [ recipient ])
    @smtp.finish
  end

  def sendEmailAlt(recipient, subject, txtBody, htmlBody)
    header = "From: #{CQPConfig::EMAIL_NAME} <#{CQPConfig::EMAIL_ADDRESS}>\nTo: #{recipient}\nSubject: #{subject}\nMIME-Version: 1.0\nContent-Transfer-Encoding: 8bit\n"
    boundary = "mime_part_boundary_" + ("%08X" % rand(0xffffffff)) + "_" + ("%08X" % rand(0xffffffff))
    header = header + "Content-Type: multipart/alternative;\n    boundary=#{boundary}\n--#{boundary}\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n\n"
    htmlstr = "--#{boundary}\nContent-Type: text/html; charset=UTF-8\nContent-Transfer-Encoding: base64\n\n#{Base64.encode64(htmlBody)}\n--#{boundary}--\n"
    txtBody = txtBody.encode(Encoding::UTF_8)
    @smtp.send_message(header + txtBody + htmlstr, CQPConfig::EMAIL_ADDRESS, [ recipient ])
    @smtp.finish
  end
end

def nonCabrilloWarning(num)
  num = num.to_i
  if 0 >= num
    return "\nWARNING: The file you uploaded does not appear to be a Cabrillo\nfile because there are *no* QSO lines detected. We are only accepting\nCabrillo files this year, so please convert your log to Cabrillo and\nupload again.\n"
  end
  ""
end

def confEmail(db, entry)
  catmap = { "county" => "CA County Expedition",
    "mobile" => "Mobile",
    "school" => "School",
    "female" => "YL Op",
    "youth" => "Youth Op",
    "newcontester" => "New Contester" }
  categories = []
  ["county", "youth", "mobile", "female", "school", "newcontester"].each { |cat|
    if entry[cat] == 1
      categories.push(catmap[cat])
    end
  }
  categories = categories.join(", ")
  confirm = OutgoingEmail.new
  confirm.sendEmail(entry["emailaddr"], "CQP 2015 Log Confirmation", "\
CQP 2015 Log Confirmation

          Callsign: #{entry['callsign_confirm']}
       Entry-Class: #{db.translateClass(entry['opclass'])}
       Power Level: #{entry['power']}
          Sent QTH: #{entry['sentqth']}
Special Categories: #{categories}
       Received at: #{entry['uploadtime']}
       Deadline at: #{CQPConfig::CONTEST_DEADLINE}
   Total QSO Lines: #{entry['maxqso']}
   Valid QSO Lines: #{entry['parseqso']}
            Log ID: #{entry['id']}
   Log SHA1 Digest: #{entry['origdigest']}
#{nonCabrilloWarning(entry['maxqso'])}
Thank you for entering the contest and submitting your log. Please
review the information listed above.  If valid QSO lines is lower 
than the total QSO lines, it means that some of the QSO lines are
not close enough to the CQP Cabrillo format for our software to
read.  To correct incorrect data, please edit and resubmit 
your log.

Check the Logs Received page to be sure your log is listed.
Here is the link: http://robot.cqp.org/.

73,

Tom NS6T
")
end


def backupEmail(db, entry)
  columns = [ "id", "callsign", "callsign_confirm", "origdigest", "opclass", "power", "uploadtime", "emailaddr", "sentqth",
              "phonenum", "county", "youth", "mobile", "female", "school", "newcontester" ]
  maxwidth = 0
  columns.each { |col|
    if col.length > maxwidth
      maxwidth = col.length
    end
  }
  body = "CQP 2015 Log Entry Received\n\n"
  columns.each { |col|
    body << ("%#{maxwidth}s: %s\n" % [col.upcase, entry[col].to_s])
  }
  confirm = OutgoingEmail.new
  confirm.sendEmail(CQPConfig::LOG_EMAIL_ACCOUNT, "CQP 2015 Log Received", body, 
                    [{ "mime" => "application/octet", "filename" => File.basename(entry['originalfile']),
                       "content" => File.read(entry['originalfile'], {:mode => "rb"}) } ])
end


def emailConfirmation(db, id)
  if entry = db.getEntry(id)
    if (entry["completed"] == 1) and entry["emailaddr"] and entry["emailaddr"].length > 0
      confEmail(db, entry)
      backupEmail(db, entry)
    end
  end
end
