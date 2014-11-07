#!/usr/bin/env ruby
# -*- encoding: utf-8; -*-
#

require 'mysql2'
require 'time'
require_relative 'callsign'

GRACETIME = 10                  # plus or minus 10 minutes
BANDS = [
  [ "160m", 1800, 2000],
  [ "80m", 3500, 4000],
  [ "40m", 7000, 7300],
  [ "20m", 14000, 14350],
  [ "15m", 21000, 21450],
  [ "10m", 28000, 29700],
  [ "6m", 50, 50],
  [ "2m", 144, 144],
  [ "1.25m", 222, 222],
  [ "70cm", 432, 432],
  [ "33cm", 902, 902]
]


MODES = %w( CW PH )

COUNTIES = %w(ALAM ALPI AMAD BUTT CALA CCOS COLU DELN ELDO FRES GLEN
 HUMB IMPE INYO KERN KING LAKE LANG LASS MADE MARN MARP MEND MERC MODO
 MONO MONT NAPA NEVA ORAN PLAC PLUM RIVE SACR SBAR SBEN SBER SCLA SCRU
 SDIE SFRA SHAS SIER SISK SJOA SLUI SMAT SOLA SONO STAN SUTT TEHA TRIN
 TULA TUOL VENT YOLO YUBA )

STATES = %w(AB AK AL AR AZ BC CO CT DE FL GA HI IA ID IL IN KS KY
 LA MA MB MD ME MI MN MO MR MS MT NC ND NE NH NJ NM NT NV NY OH OK ON
 OR PA QC RI SC SD SK TN TX UT VA VT WA WI WV WY )

OTHER = %w( DX )

class ChartDB
  def initialize(filename = "chartreuse.db")
    @db = Mysql2::Client.new(:host => "localhost",
                             :username => "expr",
                             :password => "xx42d6GcxM")
    @db.query("use Experimental")
#    @db = SQLite3::Database.new(filename)
    @db.query("create table if not exists Log (id integer primary key auto_increment, filename varchar(256))")
    @db.query("create table if not exists Multiplier (id integer primary key auto_increment, abbreviation char(4) unique not null)")
    @db.query("create table if not exists Band (id integer primary key auto_increment, name char(12) unique not null, lower integer, upper integer)")
    @db.query("create table if not exists Mode (id integer primary key auto_increment, name char(4) unique not null)")
    @db.query("create table if not exists QSO (id integer primary key auto_increment, logid integer not null, frequency integer, bandid integer, modeid integer, time bigint, sentcall varchar(24), sentbase varchar(24), sentserial integer, sentmult integer, sentmulttxt varchar(32), recvdcall varchar(24), recvdbase varchar(24), recvdserial integer, recvdmult integer, recvdmulttxt varchar (32), matchid integer, status integer)")
    begin
      @db.query("create index LowerInd on Band (lower asc)")
      @db.query("create index UpperInd on Band (upper asc)")
      @db.query("create index TimeInd on QSO (time asc)")
      @db.query("create index BandInd on QSO (bandid asc)")
      @db.query("create index SentCallInd on QSO (sentcall asc)")
      @db.query("create index BaseSentInd on QSO (sentbase asc)")
      @db.query("create index SentMultInd on QSO (sentmult asc)")
      @db.query("create index SentSerialInd on QSO (sentserial asc)")
      @db.query("create index RecvdCallInd on QSO (recvdcall asc)")
      @db.query("create index BaseRecvdInd on QSO (recvdbase asc)")
      @db.query("create index RecvdMultInd on QSO (recvdmult asc)")
      @db.query("create index RecvdSerialInd on QSO (recvdserial asc)")
      @db.query("create index MatchInd on QSO (matchid asc)")
    rescue Mysql2::Error => e
    end
    begin
        populate
    rescue Mysql2::Error => e
      # ignore
    end
    @multMap = Hash.new(nil)
    @modeMap = Hash.new(nil)
    buildmaps
  end

  def buildmaps
    @db.query("select id, abbreviation from Multiplier").each(:as => :array) { |row|
      @multMap[row[1]] = row[0].to_i
    }
    @db.query("select id, name from Mode").each(:as => :array) { |row|
      @modeMap[row[1]] = row[0].to_i
    }
  end

  def populate
    BANDS.each { |band|
      @db.query("insert into Band (name, lower, upper) values (\"#{Mysql2::Client::escape(band[0].encode("US-ASCII"))}\", #{band[1]}, #{band[2]})")
    }
    MODES.each { |mode|
      @db.query("insert into Mode (name) values (\"#{Mysql2::Client::escape(mode.encode("US-ASCII"))}\")")
    }
    COUNTIES.each { |county|
      @db.query("insert into Multiplier (abbreviation) values (\"#{Mysql2::Client::escape(county.encode("US-ASCII"))}\")")
    }
    STATES.each { |state|
      @db.query("insert into Multiplier (abbreviation) values (\"#{Mysql2::Client::escape(state.encode("US-ASCII"))}\")")
    }
    OTHER.each { |misc|
      @db.query("insert into Multiplier (abbreviation) values (\"#{Mysql2::Client::escape(misc.encode("US-ASCII"))}\")")
    }
  end

  def findBand(str)
    freq = str.to_i
    @db.query("select id from Band where lower >= #{freq} and #{freq} <= upper limit 1").each(:as => :array) { |row|
      return row[0]
    }
    nil
  end

  def findMult(str)
    @multMap[str.strip.upcase]
  end

  def findMode(str)
    @modeMap[str.strip.upcase]
  end

  def addLog(filename)
    @db.query("insert into Log (filename) values (\"#{Mysql2::Client::escape(filename)}\")")
    return @db.last_id
    nil
  end

  def parseTime(date, time)
    date = date.gsub("/","-")
    if (date =~ /\d{1,2}-\d{1,2}-\d{4}/) # mon-day-year
      date = $3 + "-" + $1 + "-" + $2
    end
    time = time.to_i
    begin
      result = Time.strptime(date + " " + ("%04d" % time) + " UTC", "%Y-%m-%d %H%M %Z")
    rescue => e
      time = fixTime(time)
      if date =~ /\A\d{2}-\d{1,2}-\d{1,2}\Z/ # two digit year
        result = Time.strptime(date + " " + ("%04d" % time) + " UTC", "%y-%m-%d %H%M %Z")
      else
        result = Time.strptime(date + " " + ("%04d" % time) + " UTC", "%Y-%m-%d %H%M %Z")
      end
    end
    result.to_i                 # returns seconds since Epoch
  end

  attr_reader :db

  def n(obj)
    if obj.nil?
      "null"
    elsif obj.instance_of?(String)
      "\"" + Mysql2::Client::escape(obj) + "\""
    else
      obj.to_s
    end
  end
      


  def addQSO(logid,
             freq, mode, datestr, timestr, sentcall, sentser, sentmult,
             recvdcall, recvdser, recvdmult)
    freq = freq.to_i
    band = findBand(freq)
    modeid = findMode(mode.upcase.encode("US-ASCII"))
    unixtime = parseTime(datestr, timestr)
    baseSent = callBase(sentcall.encode("US-ASCII"))
    baseRecvd = callBase(recvdcall.encode("US-ASCII"))
    recvdmultid = findMult(recvdmult)
    sentmultid = findMult(sentmult)
    @db.query("insert into QSO (logid, frequency, bandid, modeid, time, sentcall, sentbase, sentserial, sentmult, sentmulttxt, recvdcall, recvdbase, recvdserial, recvdmult, recvdmulttxt) values (#{n(logid)}, #{n(freq)}, #{n(band)}, #{n(modeid)}, #{n(unixtime)}, #{n(sentcall.strip.encode("US-ASCII"))}, #{n(baseSent.encode("US-ASCII"))}, #{n(sentser.to_i)}, #{n(sentmultid)}, #{n(sentmult.strip.encode("US-ASCII"))}, #{n(recvdcall.strip.encode("US-ASCII"))}, #{n(baseRecvd.encode("US-ASCII"))}, #{n(recvdser.to_i)}, #{n(recvdmultid)}, #{n(recvdmult.strip.encode("US-ASCII"))})")
  end

  def crossMatch
    # this is basically a perfect bi-directional match
    @db.query("select q1.id, q2.id from QSO as q1, QSO as q2 where q1.matchid  is null and q2.matchid is null and q1.bandid = q2.bandid and  q1.sentserial = q2.recvdserial and q1.recvdserial = q2.sentserial and q1.sentmult = q2.recvdmult and  q1.recvdmult = q2.sentmult and q1.sentmult is not null and q2.sentmult is not null and q1.id <= q2.id and (q1.time between (q2.time - #{GRACEPERIOD*60})  and (q2.time + #{GRACEPERIOD*60})) and ((q1.sentcall = q2.recvdcall) or (q1.sentbase = q2.recvdbase)) and ((q1.recvdcall = q2.sentcall) or (q1.recvdbase = q2.sentbase)) and  q1.modeid = q2.modeid").each(:as => :array) { |row|
      # record a match for both QSO records
      @db.query("update QSO set matchid = #{row[1]}, status = 4 where id = #{row[0]} limit 1")
      @db.query("update QSO set matchid = #{row[0]}, status = 4 where id = #{row[1]} limit 1")
    }
    # q1 perfectly copied q2, and q2 got mult or serial # (not both)
    @db.query("select q1.id, q2.id from QSO as q1, QSO as q2 where q1.matchid  is null and q2.matchid is null and q1.bandid = q2.bandid and  q1.recvdserial = q2.sentserial and q1.recvdmult = q2.sentmult and q1.sentmult is not null and q2.sentmult is not null and (q1.time between (q2.time - #{GRACEPERIOD*60})  and (q2.time + #{GRACEPERIOD*60})) and (q1.sentserial = q2.recvdserial or q1.sentmult = q2.recvdmult) and  ((q1.sentcall = q2.recvdcall) or (q1.sentbase = q2.recvdbase)) and ((q1.recvdcall = q2.sentcall) or (q1.recvdbase = q2.sentbase)) and  q1.modeid = q2.modeid").each(:as => :array) { |row|
      # record a perfect match q1 
      @db.query("update QSO set matchid = #{row[1]}, status = 4 where id = #{row[0]} limit 1")
      # record a D1 match for q2
      @db.query("update QSO set matchid = #{row[0]}, status = 3 where id = #{row[1]} limit 1")
    }

  end
end
