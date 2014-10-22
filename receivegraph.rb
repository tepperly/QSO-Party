#/usr/bin/env ruby
# 
# Requires the following gems:
#    svg-graph
#    
# Developed and testing with Ruby 2.1.x

require 'date'
require 'SVG/Graph/TimeSeries'

DATEREGEX=/-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})-/
START_OF_CONTEST=DateTime.new(2014,10,04,16,0,0)
HOURS_PER_BIN = 2
data = Array.new(30*24/HOURS_PER_BIN,0)         # 2-hour incremenets

ARGV.each { |filename|
  m = DATEREGEX.match(filename)
  d = DateTime.new(m[1].to_i, m[2].to_i, m[3].to_i, m[4].to_i, m[5].to_i, m[6].to_i)
  bin = ((d.to_time.to_i - START_OF_CONTEST.to_time.to_i) / (HOURS_PER_BIN*3600)).to_i
  data[bin] = data[bin] + 1 unless (bin < 0 or bin >= data.length)
}

graphdata = [ ]
data.each_index { |i|
  graphdata << Time.at(START_OF_CONTEST.to_time.to_i + i * 3600 * HOURS_PER_BIN).to_s 
  graphdata << data[i]
}
graph = SVG::Graph::TimeSeries.new( {
                                   :width => 1024,
                                   :height => 800,
                                   :graph_title => "Logs Received 2013",
                                      :show_data_values => false,
                                   :show_graph_title => true,
                                      :show_data_labels => false,
                                      :scale_y_integers => true,
                                      :x_label_format => "%m/%d/%y" } )

graph.add_data( {:data => graphdata, :title => "2013" } )

print graph.burn()
