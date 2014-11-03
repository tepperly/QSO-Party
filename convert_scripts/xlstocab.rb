#!/usr/bin/env ruby

require 'csv'
require 'date'
require 'getoptlong'

class Entrant
  def initialize
    @name = nil
    @email = nil
    @club = nil
    @optype = "multi-op"
    @callsign = nil
    @location = nil
    @power=nil
  end
  
  attr_writer :name, :email, :callsign, :location, :power, :optype, :club
  attr_reader :name, :email, :callsign, :location, :power, :optype, :club

  def to_hash
    { :name => @name,
      :email => @email,
      :power => @power,
      :optype => @optype,
      :callsign => @callsign,
      :location => @location }
  end
end

BAND_TO_FREQ = {
  "160M" => 1800,
  "160" => 1800,
  "80M" => 3500,
  "8OM" => 3500,
  "80" => 3500,
  "60M" => 5102,
  "60" => 5102,
  "40M" => 7000,
  "40" => 7000,
  "30M" => 10100,
  "30" => 10100,
  "28" => 28000,
  "20M" => 14000,
  "20" => 14000,
  "17M" => 18068,
  "17" => 18068,
  "15M" => 21000,
  "15 M" => 21000,
  "15" => 21000,
  "14" => 14000,
  "21" => 21000,
  "12M" => 24890,
  "12" => 24890,
  "10M" => 28000,
  "10" => 28000,
  "7" => 7000,
  "3.5" => 3500,
  "6M" => 50,
  "6" => 50,
  "2M" => 144,
  "2" => 144,
  "1.25M" => 222,
  "1.25" => 222,
  "70CM" => 420,
  "70" => 420,
  "33CM" => 902,
  "33" => 902,
  "23CM" => 1240,
  "23" => 1240
}

CA_COUNTIES = {
  "ALAMEDA" => "ALAM",
  "ALAM" => "ALAM",
  "MARIN" => "MARN",
  "MARN" => "MARN",
  "SAN MATEO" => "SMAT",
  "SMAT" => "SMAT",
  "ALPINE" => "ALPI",
  "ALPI" => "ALPI",
  "MARIPOSA" => "MARP",
  "MARP" => "MARP",
  "SBAR" => "SBAR",
  "SANTA BARBARA" => "SBAR",
  "AMADOR" => "AMAD",
  "AMAD" => "AMAD",
  "MENDOCINO" => "MEND",
  "MEND" => "MEND",
  "SCLA" => "SCLA",
  "SANTA CLARA" => "SCLA",
  "BUTTE" => "BUTT",
  "BUTT" => "BUTT",
  "MERCED" => "MERC",
  "MERC" => "MERC",
  "SANTA CRUZ" => "SCRU",
  "SCRU" => "SCRU",
  "CALAVERAS" => "CALA",
  "CALA" => "CALA",
  "MODO" => "MODO",
  "MODOC" => "MODO",
  "SHASTA" => "SHAS",
  "SHAS" => "SHAS",
  "COLUSA" => "COLU",
  "COLU" => "COLU",
  "MONO" => "MONO",
  "SIER" => "SIER",
  "SIERRA" => "SIER",
  "CONTRA COSTA" => "CCOS",
  "CCOS" => "CCOS",
  "MONTEREY" => "MONT",
  "MONT" => "MONT",
  "SISKIYOU" => "SISK",
  "SISK" => "SISK",
  "DEL NORTE" => "DELN",
  "DELN" => "DELN",
  "NAPA" => "NAPA",
  "SOLANO" => "SOLA",
  "SOLA" => "SOLA",
  "EL DORADO" => "ELDO",
  "ELDO" => "ELDO",
  "NEVA" => "NEVA",
  "NEVADA" => "NEVA",
  "SONOMA" => "SONO",
  "SONO" => "SONO",
  "FRESNO" => "FRES",
  "FRES" => "FRES",
  "ORANGE" => "ORAN",
  "ORAN" => "ORAN",
  "STANISLAUS" => "STAN",
  "STAN" => "STAN",
  "GLENN" => "GLEN",
  "GLEN" => "GLEN",
  "PLACER" => "PLAC",
  "PLAC" => "PLAC",
  "SUTTER" => "SUTT",
  "SUTT" => "SUTT",
  "HUMBOLDT" => "HUMB",
  "HUMB" => "HUMB",
  "PLUM" => "PLUM",
  "PLUMAS" => "PLUM",
  "TEHA" => "TEHA",
  "TEHAMA" => "TEHA",
  "IMPE" => "IMPE",
  "IMPERIAL" => "IMPE",
  "RIVE" => "RIVE",
  "RIVERSIDE" => "RIVE",
  "TRIN" => "TRIN",
  "TRINITY" => "TRIN",
  "INYO" => "INYO",
  "SACR" => "SACR",
  "SACRAMENTO" => "SACR",
  "TULARE" => "TULA",
  "TULA" => "TULA",
  "KERN" => "KERN",
  "SBEN" => "SBEN",
  "SAN BENITO" => "SBEN",
  "TUOL" => "TUOL",
  "TUOLUMNE" => "TUOL",
  "KINGS" => "KING",
  "KING" => "KING",
  "SAN BERNARDINO" => "SBER",
  "SBER" => "SBER",
  "VENTURA" => "VENT",
  "VENT" => "VENT",
  "LAKE" => "LAKE",
  "SDIE" => "SDIE",
  "SAN DIEGO" => "SDIE",
  "YOLO" => "YOLO",
  "LASSEN" => "LASS",
  "LASS" => "LASS",
  "SFRA" => "SFRA",
  "SAN FRANCISCO" => "SFRA",
  "YUBA" => "YUBA",
  "LOS ANGELES" => "LANG",
  "LANG" => "LANG",
  "SAN JOAQUIN" => "SJOA",
  "SJOA" => "SJOA",
  "MADE" => "MADE",
  "MADERA" => "MADE",
  "SLUI" => "SLUI",
  "SAN LUIS OBISPO" => "SLUI"
}

CANADIAN_PROVINCES = {
  "MARITIME" => "MR",
  "NEWFOUNDLAND" => "MR",
  "LABRADOR" => "MR",
  "NB" => "MR",
  "NL" => "MR",
  "NS" => "MR",
  "PE" => "MR",
  "MR" => "MR",
  "QUEBEC" => "QC",
  "QC" => "QC",
  "ONTARIO" => "ON",
  "ON" => "ON",
  "ONTARIO NORTH" => "ON",
  "ONN" => "ON",
  "ONTARIO EAST" => "ON",
  "ONE" => "ON",
  "GREATER TORONTO AREA" => "ON",
  "GTA" => "ON",
  "ONTARIO SOUTH" => "ON",
  "ONS" => "ON",
  "MANITOBA" => "MB",
  "MB" => "MB",
  "SASKATCHEWAN" => "SK",
  "SK" => "SK",
  "ALBERTA" => "AB",
  "AB" => "AB",
  "BRITISH COLUMBIA" => "BC",
  "BC" => "BC",
  "NORTHWEST TERRITORIES" => "NT",
  "NT" => "NT",
  "NUNAVUT" => "NT",
  "NU" => "NT",
  "YUKON TERRITORIES" => "NT",
  "YT" => "NT",
}

US_STATES = {
  "AL" => "AL",
  "ALABAMA" => "AL",
  "AL" => "AL",
  "ALASKA" => "AK",
  "AK" => "AK",
  "ARIZONA" => "AZ",
  "AZ" => "AZ",
  "ARKANSAS" => "AR",
  "AR" => "AR",
  "CALIFORNIA" => "CA",
  "CA" => "CA",
  "COLORADO" => "CO",
  "CO" => "CO",
  "CONNECTICUT" => "CT",
  "CT" => "CT",
  "DELAWARE" => "DE",
  "DE" => "DE",
  "FLORIDA" => "FL",
  "FL" => "FL",
  "GEORGIA" => "GA",
  "GA" => "GA",
  "HAWAII" => "HI",
  "HI" => "HI",
  "IDAHO" => "ID",
  "ID" => "ID",
  "ILLINOIS" => "IL",
  "IL" => "IL",
  "INDIANA" => "IN",
  "IN" => "IN",
  "IOWA" => "IA",
  "IA" => "IA",
  "KANSAS" => "KS",
  "KS" => "KS",
  "KENTUCKY" => "KY",
  "KY" => "KY",
  "LOUISIANA" => "LA",
  "LA" => "LA",
  "MAINE" => "ME",
  "ME" => "ME",
  "MARYLAND" => "MD",
  "MD" => "MD",
  "MASSACHUSETTS" => "MA",
  "MA" => "MA",
  "MICHIGAN" => "MI",
  "MI" => "MI",
  "MINNESOTA" => "MN",
  "MN" => "MN",
  "MISSISSIPPI" => "MS",
  "MS" => "MS",
  "MISSOURI" => "MO",
  "MO" => "MO",
  "MONTANA" => "MT",
  "MT" => "MT",
  "NEBRASKA" => "NE",
  "NE" => "NE",
  "NEVADA" => "NV",
  "NV" => "NV",
  "NEW HAMPSHIRE" => "NH",
  "NH" => "NH",
  "NEW JERSEY" => "NJ",
  "NJ" => "NJ",
  "NEW MEXICO" => "NM",
  "NM" => "NM",
  "NEW YORK" => "NY",
  "NY" => "NY",
  "NORTH CAROLINA" => "NC",
  "N. CAROLINA" => "NC",
  "N CAROLINA" => "NC",
  "NC" => "NC",
  "NORTH DAKOTA" => "ND",
  "N. DAKOTA" => "ND",
  "N DAKOTA" => "ND",
  "ND" => "ND",
  "OHIO" => "OH",
  "OH" => "OH",
  "OKLAHOMA" => "OK",
  "OK" => "OK",
  "OREGON" => "OR",
  "OR" => "OR",
  "PENNSYLVANIA" => "PA",
  "PA" => "PA",
  "RHODE ISLAND" => "RI",
  "RI" => "RI",
  "SOUTH CAROLINA" => "SC",
  "S CAROLINA" => "SC",
  "S. CAROLINA" => "SC",
  "SC" => "SC",
  "SOUTH DAKOTA" => "SD",
  "S DAKOTA" => "SD",
  "S. DAKOTA" => "SD",
  "SD" => "SD",
  "TENNESSEE" => "TN",
  "TN" => "TN",
  "TEXAS" => "TX",
  "TX" => "TX",
  "UTAH" => "UT",
  "UT" => "UT",
  "VERMONT" => "VT",
  "VT" => "VT",
  "VIRGINIA" => "VA",
  "VA" => "VA",
  "WASHINGTON" => "WA",
  "WA" => "WA",
  "WEST VIRGINIA" => "WV",
  "W VIRGINIA" => "WV",
  "W. VIRGINIA" => "WV",
  "WV" => "WV",
  "WISCONSIN" => "WI",
  "WI" => "WI",
  "WYOMING" => "WY",
  "WY" => "WY",
  "WASHINGTON DC" => "MD",
  "DC" => "MD"
}

def calcQTH(state, province, county)
  state = state ? state.strip.upcase.gsub(/\s{2, }/, " ") : ""
  province = province ? province.strip.upcase.gsub(/\s{2,}/, " ") : ""
  county = county ? county.strip.upcase.gsub(/\s{2,}/, " ") : ""
  if state.empty?
    if province.empty?
      if (not county.empty?) and CA_COUNTIES.has_key?(county)
        CA_COUNTIES[county]
      else
        "UNKNOWN"
      end
    else
      if CANADIAN_PROVINCES.has_key?(province)
        CANADIAN_PROVINCES[province]
      else
        "UNKNOWN"
      end
    end
  else
    if state == "CA" or state == "CALIFORNIA"
      if (not county.empty?) and CA_COUNTIES.has_key?(county)
        CA_COUNTIES[county]
      else
        "UNKNOWN"
      end
    else
      if US_STATES.has_key?(state)
        US_STATES[state]
      else
        "UNKNOWN"
      end
    end
  end
end

def calcPower(pow)
  pow = pow.strip.upcase
  case pow
  when "HIGH", "LOW", "QRP"
    pow
  when /^(\d+(\.\d+)?)(\s*W(atts?)?)?$/i
    pow = $1.to_f
    if pow <= 5
      "QRP"
    elsif pow <= 200
      "LOW"
    else
      "HIGH"
    end
  else
    "UNKNOWN"
  end
end

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
CREATED-BY: xlstocab.rb by NS6T
ENDOFHEADER


def printHeader(entrant, callsign, sentqth, power)
  if entrant.optype
    optype = entrant.optype
  else
    optype = "single-op"
  end
  print CAB_HEADER % { :callsign => callsign, :name => entrant.name,
    :email => entrant.email, :power => power, :optype => optype,
    :location => sentqth }
  if entrant.club
    print "CLUB: #{entrant.club}\n"
  end
end

def validQ(ary)
  1.upto(6) { |i|
    if ary[i].nil? or ary[i].empty?
      return false
    end
  }
  true
end

def dateTime(date, time)
  begin
    rdate = Date.strptime(date, "%m/%d/%Y")
  rescue => e
    begin
      rdate = Date.strptime(date, "%d-%b-%Y")
    rescue => e
      begin
        rdate = Date.strptime(date, "%Y-%m-%d")
      rescue => e
        rdate = Date.strptime(date, "%d-%b")
      end
    end
  end
  if time.to_s =~ /(\d{1,2}):(\d{1,2})/
    hour = $1
    min = $2
    time = hour.to_i * 100 + min.to_i
  else
    time = time.to_i
  end
  rdate.strftime("%Y-%m-%d ") + ("%04d" % time)
end

MODE = {
  "SSB" => "PH",
  "LSB" => "PH",
  "USB" => "PH",
  "FM" => "PH",
  "CW" => "CW",
  "PH" => "PH",
  "PHONE" => "PH",
  "DUPE" => "PH"
}

def serNum(num)
  begin
    return num.to_i
  rescue TypeError => e
    return 9999
  end
end

def printQSOs(qsos, callsign, sentqth)
  qsos.each {  |qso|
    if validQ(qso)
      if qso[8].nil?
        county = "XXXX"         # green treats as missing value
      else
        county = qso[8].to_s.strip.upcase.gsub(/\s{2,}/, " ")
        if CA_COUNTIES.has_key?(county)
          county = CA_COUNTIES[county]
        end
      end
      serialNum = serNum(qso[7])
      print "QSO: " + ("%5d " % BAND_TO_FREQ[qso[2].to_s.strip.upcase]) + 
        MODE[qso[3].to_s.strip.upcase] + " " + dateTime(qso[1], qso[4]) +
        (" %-11s %4d %-4s " % [callsign, serNum(qso[6]), sentqth]) + 
        (" %-11s %4d %-4s\n" % [ qso[5].to_s.strip.upcase, serialNum, county ])
    end
  }
end

def convertCSV(entrant, csv)
  lines = CSV.read(csv)
  0.upto(1) { |offset|
    if (lines[offset][1] == "California QSO Party - 2014" and lines[offset+1][1] == "Log Submission Deadline: Friday, October 31, 2014")
      if entrant.callsign
        callsign = entrant.callsign
      else
        callsign = lines[offset + 3][2].strip.upcase
      end
      if entrant.location
        sentqth = entrant.location
      else
        sentqth = calcQTH(lines[offset + 3][5], lines[offset + 4][5], lines[offset + 5][5])
      end
      if entrant.power
        power = entrant.power
      else
        power = calcPower(lines[offset + 5][2])
      end
      printHeader(entrant, callsign, sentqth, power)
      printQSOs(lines[(offset + 9)..(offset + 458)], callsign, sentqth)
      print "END-OF-LOG:\n"
      return nil
    else
      print "CSV doesn't match\n"
      print lines[offset][1].to_s + "\n"
      print lines[offset][1].to_s + "\n"
    end
  }
end


opts = GetoptLong.new(
  [ '--callsign', '-c', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--club', '-C', GetoptLong::REQUIRED_ARGUMENT ],                    
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

-C, --club club name:
   set the entrant's club

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
  when '--club'
    entrant.club = arg.upcase
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

ARGV.each { |filename|
  if (filename =~ /\.xlsx?$/)
    system("libreoffice --headless --convert-to csv --outdir tmp #{filename}")
    csvfile = "tmp/" + File.basename(filename).sub(/\.[a-z]+$/i,"") + ".csv"
  else
    csvfile = filename
  end
  convertCSV(entrant, csvfile)
}
