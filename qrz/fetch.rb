#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
#
# QRZ callsign information fetching
#

require 'net/http'
require 'nokogiri'

class QRZLookup
  LOGIN_URI="https://xmldata.qrz.com/xml/current/"
  QUERY_URI="http://xmldata.qrz.com/xml/current/"

  def initialize(username, password)
    @session_key = nil
    @username=username
    @password=password
    @loginURI = URI(LOGIN_URI)
    @queryURI = URI(QUERY_URI)
  end
  
  def startSession
    uri = URI(@loginURI)
    res = Net::HTTP.post_form(uri, 'username' => @username,
                              'password' => @password)
    if res.is_a?(Net::HTTPSuccess)
      xml = Nokogiri::XML(res.body)
      @session_key = extractKey(xml)
      printMessage(xml)
    else
      print "Failed to login to QRZ session!\n"
    end
  end
  
  def extractKey(xml)
    if xml
      xml.xpath("//qrz:Session/qrz:Key", 
                {'qrz' => 'http://xmldata.qrz.com'}).each { |match|
        return match.text
      }
    else
      print "No XML\n"
      nil
    end
    nil
  end

  def printMessage(xml)
    if xml
      xml.xpath("//qrz:Session/qrz:Message",
                {'qrz' => 'http://xmldata.qrz.com'}).each { |msg|
        print "QRZ message: #{msg.text}\n"
      }
      xml.xpath("//qrz:Session/qrz:Error", 
                {'qrz' => 'http://xmldata.qrz.com'}).each { |err|
        print "QRZ error: #{err.text}\n"
      }
    end
  end

  def lookupCall(callsign, norecurse=false)
    if not @session_key
      startSession
    end
    myuri = @queryURI.clone
    myuri.query = URI.encode_www_form({ :s => @session_key, 
                                        :callsign => callsign} )
    res = Net::HTTP.get_response(myuri)
    if res.is_a?(Net::HTTPSuccess)
      str = res.body
      if Encoding::ASCII_8BIT == str.encoding
        m = /encoding="([^"]*)"/n.match(str)
        if m
          str.force_encoding(m[1].encode("US-ASCII"))
        else
          if res.key?("content-type")
            m = /charset=([^;]+)/
            if m
              str.force_encoding(m[1].encode("US-ASCII"))
            end
          end
        end
      end
      xml = Nokogiri::XML(str)
      @session_key = extractKey(xml)
      printMessage(xml)
      if not (@session_key or norecurse) # session expired
        lookupCall(callsign, true)
      end
      return str, xml
    else
      print "QRZ query failed: #{res.code}\n"
    end
    return nil, nil
  end
end
