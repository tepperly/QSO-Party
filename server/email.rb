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
    @smtp = Net::SMTP.start(CQPConfig::EMAIL_SERVER, CQPConfig::EMAIL_PORT, CQPConfig::EMAIL_DOMAIN)
    if CQPConfig::EMAIL_USE_TLS
      @smtp.enable_starttls
    end
    if CQPConfig::EMAIL_LOGIN_REQUIRED
      @smtp.start(CQPConfig::EMAIL_DOMAIN, CQPConfig::EMAIL_ADDRESS, CQPConfig::EMAIL_PASSWORD, :login)
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
    else 
      header = header + "Content-Type: text/plain; charset=utf-8\n"
      attachstr = ""
    end
    body = body.encode(Encoding::UTF_8)
    @smtp.send_message(header + body + attachstr, CQPConfig::EMAIL_ADDRESS, [ recipient ])
    @smtp.finish
  end
end
