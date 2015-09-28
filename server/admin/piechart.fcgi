#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP admin script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

require 'fcgi'
require 'SVG/Graph/Pie'
require_relative '../database'

KNOWN_GRAPHS = {
  "power" => %w(High Low QRP ),
  "opclass" => %w(checklog multi-multi multi-single single single-assisted),
  "source" => %w(uknown email form1 form2 form3 form4)
}

def handleRequest(request, db)
  if request.has_key?("type") and KNOWN_GRAPHS.has_key?(request["type"])
    type = request["type"]
  else
    type = "opclass"
  end
  entries = db.allEntries
  stats = db.summaryStats(type, entries)
  if stats.empty?
    stats["No Data"] = 1
  end
  fields = stats.keys.sort { |x,y| -1*(stats[x] <=> stats[y]) }
  data = fields.map { |x| stats[x] }
  graph = SVG::Graph::Pie.new( { :height => 450, :width => 500, 
                                 :fields => fields })
  graph.add_data({ :data => data, :title => "#{type.capitalize} Statistics" })
  request.out("image/svg+xml") {
    graph.burn()
  }
end

db = LogDatabase.new(true)
FCGI.each_cgi {  |request|
  begin
    handleRequest(request, db)
  rescue => e
    $stderr.write(e.message + "\n")
    $stderr.write(e.backtrace.join("\n"))
    $stderr.flush()
    db.addException(e)
    raise
  end
}
