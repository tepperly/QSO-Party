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

  def new(req)
    @request = req
    @db = LogDatabase.new
    @timestamp = Time.new.utc

  end

  def splitIntoColumns(callsigns)
    signsPerColumn = callsigns / NUMCOLUMNS
    leftOvers = callsigns % NUMCOLUMNS
    table = Array.new(NUMCOLUMNS)
    base = 0
    table.each_index { |i|
      numInCol = signsPerColumns + ((i <= leftOvers) ? 1 : 0)
      table[i] = callsigns[base, numInCol]
      base = base + numInCol
    }
    table
  end

  def generateHTML(table)
    count = 0
    @request.out() {
      @request.html() { 
        @request.head() { 
          @request.title("CQP Callsigns Confirmed Received")
        }
        @request.html() {
          @request.table(){
            @request.tr() {
              table.each_index { |i|
                sign = table[i][count]
                if sign
                  @request.td() { sign }
                else
                  @request.td() { "&nbsp;" }
                end
              }
            }
            count = count + 1
          }
        }
      }
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
