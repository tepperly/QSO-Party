#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP upload script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#
require 'cgi'
require_relative 'database'


class CallsignReport
  NUMCOLUMNS = 4

  def initialize(req)
    @request = req
    @db = LogDatabase.new
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

  def generateHTML(table)
    count = 0
    @request.out() {
      html = @request.html() { 
        @request.head() { 
          @request.title { "CQP Callsigns Confirmed Received" } +
          @request.link("href" => "cqprecvd.css", "rel"=>"stylesheet")  { }+
          @request.style() {
            "th, td { 
               width: " + (100.0/table.length).to_s + "%;
             }
           "
          }
        } +
        @request.body() {
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
          @request.p() { "Data based on logs received before: " +
            @timestamp.to_s + "." }
        }
      }
      CGI::pretty( html)
    }
  end

  def report
    callsigns = @db.callsignsRcvd()
    table = splitIntoColumns(callsigns)
    generateHTML(table)
  end
end

csr = CallsignReport.new(CGI.new("html4"))
csr.report
