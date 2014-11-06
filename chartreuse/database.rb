#!/usr/bin/env ruby
# -*- encoding: utf-8; -*-
#

require 'sqlite3'
require 'time'

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
    @db = SQLite3::Database.new(filename)
    @db.execute("create table if not exist Log (id integer primary key asc autoincrement, filename varchar(256))")
    @db.execute("create table if not exist Multiplier (id integer primary key asc autoincrement, abbreviation char(4) unique not null)")
    @db.execute("create table if not exist Band (id integer primary key asc autoincrement, name char(12) unique not null, lower integer, upper integer)")
    @db.execute("create table if not exist Mode (id integer primary key asc autoincrement, name char(4) unique not null)")
    @db.execute("create table if not exist QSO (id integer primary key asc autoincrement, logid integer not null, frequency integer, bandid integer, modeid integer, time bigint, sentcall varchar(24), sentbase varchar(24), sentserial integer, sentmult integer, sentmulttxt varchar(32), recvdcall varchar(24), recvdbase varchar(24), recvdserial integer, recvdmult integer, recvdmulttxt varchar (32))")
    populate
  end

  def populate
    BANDS.each { |band|
      @db.execute("insert into Band (name, lower, upper) values (\"#{band[0]}\", #{band[1]}, #{band[2]})")
    }
    MODES.each { |mode|
      @db.execute("insert into Mode (name) values (\"#{mode}\")")
    }
    COUNTIES.each { |county|
      @db.execute("insert into Multiplier (abbreviation) values (\"#{county}\")")
    }
    STATES.each { |state|
      @db.execute("insert into Multiplier (abbreviation) values (\"#{state}\")")
    }
    OTHER.each { |misc|
      @db.execute("insert into Multiplier (abbreviation) values (\"#{misc}\")")
    }
  end

  def findBand(str)
    freq = str.to_i
    @db.execute("select id from Band where lower >= #{freq} and #{freq} <= upper limit 1") { |row|
      return row[0]
    }
    nil
  end

  def findMult(str)
    @db.execute("select id from Multiplier where abbreviation=\"#{str}\" limit 1") { |row|
      return row[0]
    }
    nil
  end

  def findMode(str)
    @db.execute("select id from Mode where name = \"#{str}\" limit 1") { |row|
      return row[0]
    }
    nil
  end

  def addLog(filename)
    @db.execute("insert into Log (filename) values (#{filename})")
    @db.execute("select last_insert_rowid()") { |row|
      return row[0]
    }
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


  def addQSO(logid,
             freq, mode, datestr, timestr, sentcall, sentser, sentmult,
             recvdcall, recvdser, recvdmult)
    freq = freq.to_i
    band = findBand(freq)
    modeid = findMode(mode)
    unixtime = parseTime(datestr, timestr)
    baseSent = callBase(sentcall)
    baseRecvd = callBase(recvdcall)
    recvdmultid = findMult(recvdmult)
    sentmultid = findMult(sentmult)
    @db.execute("insert into QSO (logid, frequency, bandid, modeid, time, sentcall, sentbase, sentserial, sentmult, sentmulttxt, recvdcall, recvdbase, recvdserial, recvdmult, recvdmulttxt) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [logid, freq, band, modeid, unixtime, sentcall, baseSent,
                  sentser.to_i, sentmultid, sentmult, recvdcall, baseRecvd,
                  recvdser.to_i, recvdmultiid, recvdmult ] )
  end

end
