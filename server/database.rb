#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# CQP upload database module
# Tom Epperly NS6T
# ns6t@arrl.net
#
#
# create user 'cqpuser'@'localhost' identified by 'cqp234ddx';
# grant all on CQPUploads.* to 'cqpuser'@'localhost' ;
# flush privileges;
#

require_relative 'config'
require 'mysql2'

class DatabaseError < Exception
end


class LogDatabase
  def initialize
    @connection = nil
    @mapping = Hash.new("")
    @mapping["single"] = "Single-Op"
    @mapping["multi-single"] = "Multi-single"
    @mapping["multi-multi"] = "Multi-multi"
    @mapping["checklog"] = "Checklog"
  end

  DBTIMEFORMAT="%Y-%m-%d %H:%M:%S.%L"
  MAXIDINT=9007199254740992  # chosen due to Javascript's biggestInt

  def connect
    if not @connection
      @connection = Mysql2::Client.new(:host => CQPConfig::DATABASE_HOST,
                                       :username => CQPConfig::DATABASE_USER,
                                       :reconnect => true,
                                       :password => CQPConfig::DATABASE_PASSWORD)
      if @connection 
        @connection.query("create database if not exists CQPUploads character set = 'utf8';")
        @connection.query("use CQPUploads;")
        @connection.query("create table if not exists CQPLog (id bigint primary key, callsign varchar(32), callsign_confirm varchar(32), userfilename varchar(1024), originalfile varchar(1024), asciifile varchar(1024), logencoding varchar(32), origdigest char(40), opclass ENUM('checklog', 'multi-multi', 'multi-single', 'single'), power ENUM('High', 'Low', 'QRP'), uploadtime datetime, uploadinstant double, emailaddr varchar(256), sentqth varchar(256), phonenum varchar(32), comments varchar(4096), maxqso int, parseqso int, county tinyint(1) unsigned,  youth tinyint(1) unsigned, mobile tinyint(1) unsigned, female tinyint(1) unsigned, school tinyint(1) unsigned, newcontester tinyint(1) unsigned, completed tinyint(1) unsigned not null default 0, source enum('unknown', 'email', 'form1', 'form2', 'form3') not null default 'unknown', index callindex (callsign asc), index calltwoind (callsign_confirm asc), index uploadtimeind (uploadtime asc), index uploadinstind (uploadinstant asc));")
        @connection.query("create table if not exists CQPError (id int auto_increment primary key, message varchar(256), traceback varchar(1024), timestamp datetime);")
        @connection.query("create table if not exists CQPExtra (id bigint primary key auto_increment, logid bigint, callsign varchar(32), opclass ENUM('checklog', 'multi-multi', 'multi-single', 'single'), power ENUM('High', 'Low', 'QRP'), uploadtime datetime, emailaddr varchar(256), sentqth varchar(256), phonenum varchar(32), comments varchar(4096), county tinyint(1) unsigned,  youth tinyint(1) unsigned, mobile tinyint(1) unsigned, female tinyint(1) unsigned, school tinyint(1) unsigned, newcontester tinyint(1) unsigned, source enum('unknown', 'email', 'form1', 'form2', 'form3') not null default 'unknown', index uploadtimeind (uploadtime asc));")
        @connection.query("create table if not exists CQPWorked (id bigint primary key auto_increment, logid bigint not null, callsign varchar(32) not null, count smallint unsigned not null default 0, index logind (logid asc), index callind (callsign asc));")
      end
    else
      @connection.query("use CQPUploads;")  # useful for database reconnects
    end
    @connection
  end

  def getOne(str)
    result = @connection.query(str, :as => :array)
    if result
      result.each { |row|
        return row[0]
      }
    end
    nil
  end

  def getID
    connect
    if @connection
      id = nil
      tries = 0
      while not id and tries  < 20
        begin
          id = getOne("select cast(rand()*#{MAXIDINT} as signed integer) as id;").to_i
          @connection.query("insert into CQPLog (id) values (#{id});")
        rescue Mysql2::Error    # ID collision with previous entry
          id = nil
          tries = tries + 1
        end
      end
    end
    id
  end

  def addLog(id, callsign, userfile, origfile, asciifile, encoding, timestamp, digest, source)
    connect
    if @connection
      if id
        id = id.to_i
        if not %w( email form1 form2 form3 ).index(source)
          source = "unknown"
        end
        @connection.query("update CQPLog set callsign='#{Mysql2::Client::escape(callsign)}', userfilename='#{Mysql2::Client::escape(userfile)}', originalfile='#{Mysql2::Client::escape(origfile)}', asciifile='#{Mysql2::Client::escape(asciifile)}', logencoding='#{Mysql2::Client::escape(encoding)}', uploadtime='#{timestamp.strftime(DBTIMEFORMAT)}', uploadinstant=#{timestamp.to_f}, origdigest='#{Mysql2::Client::escape(digest)}', source='#{source}' where id = #{id.to_i} limit 1;")
        return id
      end
    end
    raise DatabaseError, "Foo"
  end

  def getSourceStates(ids)
    result = Hash.new
    connect
    if @connection
      @connection.query("select source, count(*) from CQPLog where id in (" + ids.join(", ") + ") group by source asc order by source asc;")
    end
    
  end

  def getASCIIFile(id)
    connect
    filename = nil
    if @connection
      str = "select asciifile from CQPLog where id = #{id.to_i} limit 1;"
      filename = getOne(str)
    end
    filename
  end

  def getCallsign(id)
    connect
    callsign = nil
    if @connection
      str = "select callsign_confirm from CQPLog where id = #{id.to_i} limit 1;"
      callsign = getOne(str)
    end
    callsign
  end

  def numSpecial(entries, category)
    count = 0
    connect
    if @connection
      count = getOne("select count(*) from CQPLog where id in (#{entries.join(', ')}) and #{category};")
    end
    count
  end

  def getIncomplete(id)
    connect
    callsign = nil
    if @connection
      res = @connection.query("select callsign, uploadtime from CQPLog where id = #{id.to_i} limit 1;")
      res.each(:as => :array) { |row|
        return row[0], row[1]
      }
    end
    return nil, nil
  end

  def addExtra(id,callsign, email, opclass, power, sentqth, phone, comments, county, youth, mobile, female, school, newcontester, source)
    connect
    if @connection
      id = id.to_i
      if not %w( email form1 form2 form3 ).index(source)
        source = "unknown"
      end
      queryStr = "update CQPLog set callsign_confirm='#{Mysql2::Client::escape(callsign)}', opclass='#{Mysql2::Client::escape(opclass)}', power='#{Mysql2::Client::escape(power)}', emailaddr='#{Mysql2::Client::escape(email)}', sentqth='#{Mysql2::Client::escape(sentqth)}', phonenum='#{Mysql2::Client::escape(phone)}', comments='#{Mysql2::Client::escape(comments)}', county=#{county.to_i}, youth=#{youth.to_i}, mobile= #{mobile.to_i}, female=#{female.to_i}, school=#{school.to_i}, newcontester=#{newcontester.to_i}, completed=1, source='#{Mysql2::Client::escape(source)}' where id = #{id.to_i} limit 1;"
#      $outfile.write(queryStr + "\n");
      @connection.query(queryStr)
      @connection.query("insert into CQPExtra (logid, callsign, opclass, power, uploadtime, emailaddr, sentqth, phonenum, comments, county, youth, mobile, female, school, newcontester, source) values (#{id}, '#{Mysql2::Client::escape(callsign)}', '#{Mysql2::Client::escape(opclass)}', '#{Mysql2::Client::escape(power)}', NOW(), '#{Mysql2::Client::escape(email)}', '#{Mysql2::Client::escape(sentqth)}', '#{Mysql2::Client::escape(phone)}', '#{Mysql2::Client::escape(comments)}', #{county.to_i}, #{youth.to_i}, #{mobile.to_i}, #{female.to_i}, #{school.to_i}, #{newcontester.to_i}, source='#{Mysql2::Client::escape(source)}');")
      true
    else
      false
    end
  end
  
  def addException(e)
    connect
    if @connection
      @connection.query("insert into CQPError (message, traceback, timestamp) values ('#{Mysql2::Client::escape(e.message)}', '#{Mysql2::Client::escape(e.backtrace.join("\n"))}', NOW());")
    end
  end

  def addQSOCount(id, maxq, validq)
    connect
    if @connection
      id = id.to_i
      @connection.query("update CQPLog set maxqso=#{maxq.to_i}, parseqso=#{validq.to_i} where id = #{id.to_i} limit 1;")
    end
  end

  def getQSOCounts(id)
    connect
    if @connection
      result = @connection.query("select maxqso, parseqso from CQPLog where id = #{id.to_i} limit 1;")
      result.each { |row|
        return row["maxqso"], row["parseqso"]
      }
    end
    return 0, 0
  end

  def callsignsRcvd
    result = [ ]
    field = 'callsign_confirm'
    connect
    if @connection
      res = @connection.query("select distinct #{field} from CQPLog where completed order by #{field} asc;")
      res.each { |row|
        sign = row[field]
        result << sign unless ("UNKNOWN" == sign or "" == sign)
      }
    end
    return result
  end

  def logDates
    connect
    if @connection
      res = @connection.query("select min(uploadtime), max(uploadtime) from CQPLog where completed;")
      res.each(:as => :array) { |row|
        return row[0], row[1]
      }
    end
    return nil, nil
  end

  def getEntry(id)
    connect
    if id and @connection
      res = @connection.query("select * from CQPLog where id = #{id} limit 1;")
      res.each { |row|
        result = Hash.new
        row.each { |column, value|
          result[column] = value
        }
        return result
      }
    end
    nil
  end

  def translateClass(str)
    @mapping[str]
  end

  def allEntries
    connect
    result = nil
    if @connection
      result = [ ]
      res = @connection.query("select l1.id from CQPLog l1 left outer join CQPLog l2 on (l1.callsign_confirm = l2.callsign_confirm and l1.uploadinstant < l2.uploadinstant and l2.completed) where l2.id is null and l1.completed order by l1.callsign_confirm asc;");
      res.each(:as => :array) { |row|
        result << row[0].to_i
      }
    end
    result
  end

  def incompleteEntries
    connect
    result = nil
    if @connection
      result = [ ]
      res = @connection.query("select l1.id from CQPLog l1 left outer join CQPLog l2 on (l1.callsign = l2.callsign and l2.completed) where l2.id is null and not l1.completed group by l1.callsign asc order by l1.callsign asc;");
      res.each(:as => :array) { |row|
        result << row[0].to_i
      }
    end
    result
  end

  def addWorked(logid, worked)
    connect
    if @connection
      worked.each { |key, value|
        @connection.query("insert into CQPWorked (logid, callsign, count) values (#{logid.to_i}, \"#{Mysql2::Client::escape(key)}\", #{value.to_i});")
      }
    end
  end

  def workedStats(entries, threshold=0)
    results = Hash.new(0)
    connect
    if @connection
      res = @connection.query("select callsign, sum(count) as tot from CQPWorked where logid in (#{entries.join(', ')}) group by callsign having tot >= #{threshold.to_i};")
      res.each(:as => :array) { |row|
        results[row[0]] = row[1].to_i
      }
    end
    results
  end

  def summaryStats(field, entries)
    results = Hash.new(0)
    connect
    if @connection
      res = @connection.query("select #{field}, count(*) from CQPLog where id in (#{entries.join(", ")}) group by #{field};")
      res.each(:as => :array) { |row|
        results[row[0]] = row[1].to_i
      }
    end
    results
  end
end
