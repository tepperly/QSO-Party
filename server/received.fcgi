#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP upload script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#
require 'fcgi'
require_relative 'database'


class CallsignReport
  NUMCOLUMNS = 4

  def initialize(req, db = nil)
    @request = req
    if db
      @db = db
    else
      @db = LogDatabase.new
    end
    @timestamp = Time.new.utc

  end

  def splitIntoColumns(callsigns)
    signsPerColumn = callsigns.length / NUMCOLUMNS
    leftOvers = callsigns.length % NUMCOLUMNS
    table = Array.new(NUMCOLUMNS)
    base = 0
    table.each_index { |i|
      numInCol = signsPerColumn + ((i < leftOvers) ? 1 : 0)
      table[i] = callsigns[base, numInCol]
      base = base + numInCol
    }
    table
  end

  def generateHTML(table, num)
    count = 0
    @request.out() {
      html = @request.html() { 
        @request.head() { 
          @request.link("href" => "/cqp/favicon.ico", "rel" => "icon", "sizes" => "16x16 32x32 40x40 64x64 128x128", "type" => "image/vnd.microsoft.icon" ) +
          @request.meta("http-equiv" => "Content-Type",
                        "content" => "text/html; charset=UTF-8") +
          @request.title { "CQP Callsigns Confirmed Received" } +
          @request.link("href" => "/cqp/server/cqprecvd.css", 
                        "rel"=>"stylesheet", 
                        "type" => "text/css")  { }+
          @request.style("type" => "text/css") {
            "th, td { 
               width: " + (100.0/table.length).to_s + "%;
             }
           "
          }
        } +
        @request.body() {
          @request.div("id" => "masthead") {
             @request.img("src" => "/cqp/images/cqplogo80075.jpg", "alt" => "California QSO Party") 
          } +
          @request.h1() { "CQP 2014 Logs Received" } +
          @request.p() { "The call signs for all logs received are
    shown below. Please ensure any log you've submitted is shown
    here." } +
          @request.table(){
            @request.tbody()  {
              (0..(table[0].length-1)).inject("") { |str, j|
                str = str + 
                @request.tr("class" => ((j+1).even? ? "evenRow" : "oddRow")) {
                  (0..(table.length-1)).inject("") { |row, i|
                    sign = table[i][j]
                    if sign
                      row = row + @request.td() { sign }
                    else
                      row = row + @request.td() { "&nbsp;" }
                    end
                  }
                }
              }
            }
          } +
          @request.p() { "Data based on #{num} logs received before: " +
            @timestamp.to_s + "." }
        }
      }
      CGI::pretty( html)
    }
  end

  def report
    callsigns = @db.callsignsRcvd()
    table = splitIntoColumns(callsigns)
    generateHTML(table, callsigns.length)
  end
end

ldb = LogDatabase.new
FCGI.each_cgi("html4Tr") { |cgi|
  csr = CallsignReport.new(cgi, ldb)
  csr.report
}
