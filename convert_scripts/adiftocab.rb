#!/usr/bin/env ruby
# Convert ADIF to CQP Cabrillo
# by Tom Epperly
# ns6t@arrl.net

require_relative 'adif'
require 'getoptlong'

class Entrant
  def initialize
    @name = nil
    @email = nil
    @optype = "multi-op"
    @callsign = nil
    @location = nil
    @power="high"
  end
  
  attr_writer :name, :email, :callsign, :location, :power, :optype
  attr_reader :name, :email, :callsign, :location, :power, :optype

  def to_hash
    { :name => @name,
      :email => @email,
      :power => @power,
      :optype => @optype,
      :callsign => @callsign,
      :location => @location }
  end
end

opts = GetoptLong.new(
  [ '--callsign', '-c', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--email', '-e', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--optype', '-o', GetoptLong::REQUIRED_ARGUMENT ],                     
  [ '--name', '-n', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--power', '-p', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--location', '-l', GetoptLong::REQUIRED_ARGUMENT ]
)

def printHelp
  puts <<-EOF
adiftocab.rb [OPTIONS] adiffile.adi

-h, --help:
   show help

-c, --callsign callsign:
   set the entrant's callsign

-e, --email address:
   set the entrant's email address

-p, --power (high|low|QRP):
   set the entrant's power level

-n, --name name:
   set the entrant's name

-l, --location multiplier:
   set the entrant's location from the list of CQP multipliers
EOF
end

entrant = Entrant.new
opts.each { |opt, arg|
  case opt
  when '--help'
    printHelp
  when '--callsign'
    entrant.callsign = arg.upcase
  when '--name'
    entrant.name = arg.strip
  when '--optype'
    entrant.optype = arg.strip
  when '--location'
    entrant.location = arg.strip.upcase
  when '--email'
    entrant.email = arg.strip
  when '--power'
    entrant.power = arg.strip
  end
}

CAB_HEADER=<<-ENDOFHEADER
START-OF-LOG: 3.0
CALLSIGN: %{callsign}
CONTEST: CA-QSO-PARTY
NAME: %{name}
EMAIL: %{email}
CATEGORY-POWER: %{power}
CATEGORY-OPERATOR: %{optype}
LOCATION: %{location}
CATEGORY-STATION: FIXED
CREATED-BY: adiftocab.rb by NS6T
ENDOFHEADER

BAND_TO_FREQ = {
  "160M" => 1.8,
  "80M" => 3.5,
  "60M" => 5.102,
  "40M" => 7,
  "30M" => 10.1,
  "20M" => 14,
  "17M" => 18.068,
  "15M" => 21,
  "12M" => 24.890,
  "10M" => 28,
  "6M" => 50,
  "2M" => 144,
  "1.25M" => 222,
  "70CM" => 420,
  "33CM" => 902,
  "23CM" => 1240
}

def freq(qso)
  if qso.has_key?("freq")
    frequency = qso.frequency.to_f     # frequency in MHz
  else
    if qso.has_key?("band")
      frequency = BAND_TO_FREQ[qso.getText("band").upcase]
    else
      frequency = 0
    end
  end
  case frequency
  when 50..54
    return "   50"
  when 144..148
    return "  144"
  when 222..225
    return "  222"
  when 420..450
    return "  432"
  when 902..925
    return "  902"
  else
    return "%5d" % (frequency*1000).to_i
  end
end

def mode(qso)
  case qso.mode
  when "AM", "FM", "SSB", "LSB", "USB"
    return "PH"
  when "CW"
    return "CW"
  else
    return "RY"
  end
end

def dateTime(qso)
  date = qso.qso_date
  time = qso.qso_time
  return date.strftime("%Y-%m-%d ") + ("%02d" % time.hours) + 
    ("%02d " % time.minutes )
end

def sentExchange(entrant, qso)
  if qso.has_key?("n3fjp_serial_no_sent")
    serial = qso.getText("n3fjp_serial_no_sent").to_i
    return ("%4d " % serial) + ("%-4s" % entrant.location)
  elsif qso.has_key?("stx")
    serial = qso.getText("stx").to_i
    return  ("%4d " % serial) + ("%-4s" % entrant.location)
  elsif qso.has_key?("stx_string")
    serial = qso.getText("stx_string").to_i
    return  ("%4d " % serial) + ("%-4s" % entrant.location)
  else
    raise "Unknown ADIF format"
  end
end

def receivedExchange(qso)
  if qso.has_key?("app_wl32_remarks")
    info = qso.getText("app_wl32_remarks").split[0..1]
    return "%4d %-4s" % [info[0].to_i, info[1].to_s]
  elsif qso.has_key?("n3fjp_serial_no_rcvd")
    serial = qso.getText("n3fjp_serial_no_rcvd").to_i
    mult = qso.getText("n3fjp_spcnum").strip
    return "%4d %-4s" % [serial, mult]
  elsif qso.has_key?("srx_string") and qso.has_key?("srx")
    return "%4d %-4s" % [ qso.getText("srx").to_i , qso.getText("srx_string").strip ]
  elsif qso.has_key?("srx")
    return "%4d XXXX" % [ qso.getText("srx").to_i ]
  elsif qso.has_key?("srx_string")
    return "%4d XXXX" % [ qso.getText("srx_string").to_i ]
  else
    raise "Unknown ADIF format"
  end
end

def outputQSO(entrant, qso)
  print "QSO: " + freq(qso) + " " + mode(qso) + " " + dateTime(qso) +
    " " + ("%-11s" % entrant.callsign) + " " + sentExchange(entrant, qso) + " " +
    ("%-11s" % qso.call) + " " + receivedExchange(qso) + "\n"
end

def generateCabrillo(entrant, qsos)
  print (CAB_HEADER % entrant.to_hash)
  qsos.each { |qso|
    outputQSO(entrant, qso)
  }
  print "END-OF-LOG:\n"
end

ARGV.each { |arg|
  qsos = [ ]
  open(arg, "r:ascii") { |io|
    parseFile(io, qsos)
  }
  qsos.sort!
  generateCabrillo(entrant, qsos)
}
