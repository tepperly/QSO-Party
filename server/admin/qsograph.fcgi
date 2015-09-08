#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP admin script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

require 'fcgi'
require 'SVG/Graph/TimeSeries'
require_relative '../database'

BANDS = %w(160M 80M 40M 20M 15M 10M 6M 2M 222 432 902)
MODES = %w(PH CW)
MINUTES_PER_BIN = 15
CONTEST_HOURS = 30
CONTEST_START = Time.utc(2015, 10, 3, 16, 0)
CONTEST_END = CONTEST_START + CONTEST_HOURS*60*60

def bandFromFreq(freq)
  band = nil
  case freq.to_i
  when 1800..2000
    band = "160M"
  when 3500..4000
    band = "80M"
  when 7000..7300
    band = "40M"
  when 14000..14300
    band = "20M"
  when 21000..21450
    band = "15M"
  when 28000..29700
    band = "10M"
  when 50
    band = "6M"
  when 144
    band = "2M"
  when 222
    band = "222"
  when 432
    band = "432"
  when 902
    band = "902"
  end
  band
end
  
def dataFromLog(filename, bandtotals, timedata, details)
  open(filename, "r:ascii") { |io|
    content = io.read
    content.scan(/^qso:\s+(\d+)\s+([a-z]+)\s+(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{2})(\d{2})/i) { |freq, mode, year, month, day, hour, minute| 
      band = bandFromFreq(freq.to_i)
      if band
        bandtotals[band] = bandtotals[band] + 0.5
        begin
          t = Time.utc(year, month, day, hour, minute)
          if t.between?(CONTEST_START, CONTEST_END)
            bin = ((t - CONTEST_START)/(MINUTES_PER_BIN * 60)).to_i
            timedata[bin][band] = timedata[bin][band]  + 0.5
            case mode.upcase
            when 'CW'
              details[bin][band]['CW'] = details[bin][band]['CW'] + 0.5
            when 'PH', 'SSB'
              details[bin][band]['PH'] = details[bin][band]['PH'] + 0.5
            end
          end
        rescue => e
          # ignore error
        end
      end
    }
  }
end

def convertData(band, timedata)
  result = Array.new
  timedata.each_index { |i|
    result << (CONTEST_START + MINUTES_PER_BIN * 60 * i)
    result << timedata[i][band]
  }
  result
end

def dataLines(timedata, bands)
  result = ""
  timedata.each_index { |i|
    result << (CONTEST_START + MINUTES_PER_BIN * 60 *i).strftime("%m/%d/%Y %H:%M")
    bands.each { |band|
      result << ","
      result << timedata[i][band].to_s
    }
    result << "\n"
  }
  result
end

def buildCSV(request, timedata, bandtotals)
  bands = BANDS.select { |band| bandtotals[band] > 0 }
  request.out("status" => "OK", "type" => "text/csv", "charset" => "us-ascii",
              "Content-Disposition" => "attachment; filename=qsograph.csv" ) {
    "\"Date/Time\"," + bands.map { |b| "\"" + b + "\"" }.join(",") + "\n" +
    dataLines(timedata, bands)
  }
end

def crossProd(a1, a2)
  result = Array.new
  a1.each { |e1|
    a2.each { |e2|
      result << (e1 + ' ' + e2)
    }
  }
  result
end

def dateLines2(details, bands)
  result = ""
  details.each_index { |i|
    result << (CONTEST_START + MINUTES_PER_BIN * 60 *i).strftime("%m/%d/%Y %H:%M")
    bands.each { |band|
      MODES.each { |mode|
        result << ","
        result << details[i][band][mode].to_s
      }
    }
    result << "\n"
  }
  result
end

def buildCSV2(request, details, bandtotals)
  bands = BANDS.select { |band| bandtotals[band] > 0 }
  request.out("status" => "OK", "type" => "text/csv", "charset" => "us-ascii",
              "Content-Disposition" => "attachment; filename=qsograph.csv" ) {
    "\"Date/Time\"," + crossProd(bands, MODES).map { |b| "\"" + b + "\"" }.join(",") + "\n" +
    dateLines2(details, bands)
  }
end

def emptyData
  result = Array.new
  (1 + CONTEST_HOURS * 60 / MINUTES_PER_BIN).to_i.times { |i|
    result << (CONTEST_START + MINUTES_PER_BIN * 60 * i)
    result << 0
  }
  { :data => result, :title => "No Data" }
end


def buildGraph(request, timedata, bandtotals)
  graph = SVG::Graph::TimeSeries.new( { :width => 1024,
                                        :height => 800,
                                        :graph_title => "QSOs by Band for CQP #{CONTEST_START.strftime("%Y")}",
                                        :show_graph_title => true,
                                        :show_data_values => false,
                                        :timescale_divisions => "2 hours",
                                        :stacked => true,
                                        :area_fill => true,
                                        :y_title => "# QSOs",
                                        :show_y_title => true,
                                        :x_title => "Time (UTC)",
                                        :show_x_title => true,
                                        :scale_y_integers => true,
                                        :x_label_format => "%H:%M" } )
  num = 0
  BANDS.each {  |band|
    if bandtotals[band] > 0
      num = num + 1
      graph.add_data({ :data => convertData(band, timedata), :title => band })
    end
  }
  if num == 0
    graph.add_data(emptyData)
  end
  request.out("image/svg+xml") {
    graph.burn()
  }
end

def makeGraph(request, db)
  data = Array.new((CONTEST_HOURS*60/MINUTES_PER_BIN).to_i+1)
  detail = Array.new((CONTEST_HOURS*60/MINUTES_PER_BIN).to_i+1)
  bandtotals = Hash.new(0)
  data.each_index { |i|
    data[i] = Hash.new(0)
    detail[i] = Hash.new
    BANDS.each { |band|
      detail[i][band] = Hash.new(0)
    }
  }
  entries = db.allEntries
  entries.each { |id|
    dataFromLog(db.getASCIIFile(id), bandtotals, data, detail)
  }
  if request.has_key?("type") 
    case request["type"]
    when "csv"
      buildCSV(request, data, bandtotals)
    when "csv2"
      buildCSV2(request, detail, bandtotals)
    else
      buildGraph(request, data, bandtotals)
    end
  else
    buildGraph(request, data, bandtotals)
  end
end

db = LogDatabase.new(true)
FCGI.each_cgi { |request|
  begin
    makeGraph(request, db)
  rescue => e
    $stderr.write(e.message + "\n")
    $stderr.write(e.backtrace.join("\n"))
    $stderr.flush()
    db.addException(e)
    raise
  end
}
