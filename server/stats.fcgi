#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP upload statistics script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#
require 'fcgi'
require 'json'
require_relative 'database'

db = LogDatabase.new(true) # read-only db connection

FCGI.each_cgi { |cgi|
  count, date = db.uploadStats
  if not (count.nil? or date.nil?)
    result = { "count" => count.to_i, "date" => date.to_s }
  else
    result = { "count" => 0, "date" => nil }
  end
  cgi.out("text/javascript") {
    result.to_json
  }
}
