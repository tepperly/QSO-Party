#!/usr/bin/env ruby

require 'csv'
require 'set'

def rootCall(call)
  # adapted from WX5S's CQP_RootCall.pm
  call = call.upcase.gsub(/\s+/,"") # remove space and convert to upper case
  parts = call.split("/")
  case parts.length
  when 0
    return call
  when 1
    return parts[0]
  when 2
    if parts[0] =~ /\d\z/ or (parts[0] !~ /\d/ and parts[1] !~ /\A\d\z/)
      return parts[1]
    else
      return parts[0]
    end

  end
end

def charClasses(str)
  classes = Hash.new
  if str =~ /[A-Z]/
    classes[:alpha] = true
  end
  if str =~ /\d/
    classes[:digit] = true
  end
  classes
end

def compareCallParts(x, y)
  if x == y
    0
  else
    xc = charClasses(x)
    yc = charClasses(y)
    cmp = (xc.size <=> yc.size)
    if cmp != 0
      cmp
    else
      if xc.length == 2         # both have numbers and letters
        if x =~ /\d\z/ and y !~ /\d\z/
          -1
        elsif x !~ /d\z/ and y =~ /\d\z/
          1
        else
          return x.length <=> y.length
        end
      elsif xc.length == 1
        if xc.has_key?(:alpha) and yc.has_key?(:digit)
          1
        elsif xc.has_key?(:digit) and yc.has_key?(:alpha)
          -1
        else
          return x.length <=> y.length
        end
      else                      # neither has alpha or digits
        return x.length <=> y.length
      end
    end
  end
end

def callBase(str)
  str = str.upcase.encode("US-ASCII")
  str.gsub!(/\s+/,"")
  parts = str.split("/")
  case parts.length
  when 0
    str
  when 1
    parts[0]
  when 2
    if parts[0] =~ /\d\z/ or (parts[0] !~ /\d/ and parts[1] !~ /\A\d\z/)
      parts[1]
    else 
      parts[0]
    end
  else
    return parts[1]
  end
  str
end

def scanQSOs(filename, aliases, potLogs)
  sentlocs = Hash.new(0)
  open(filename, "r:ascii") { |login|
    content = login.read
    content.scan(/^QSO:\s+\d+\s+\w+\s+\d+-\d+-\d+\s+\d+\s+\S+\s+\d+\s+(\w+)\s+([a-z0-9\/]+)\s+\d+\s+(\w+)/i) { |qso|
      sentloc = qso[0].upcase.strip
      if aliases.has_key?(sentloc)
        sentlocs[aliases[sentloc]] = sentlocs[aliases[sentloc]] + 1
      end
      callsign = callBase(qso[1].upcase.strip)
      location = qso[2].upcase.strip
      if aliases.has_key?(location)
        potLogs[aliases[location]][callsign] = potLogs[aliases[location]][callsign] + 1
      end
    }
    if not sentlocs.empty?
      loc, count = sentlocs.max_by{|k,v| v}
      return loc
    end
    return nil
  }
end

def bigLogs(logHash, alreadyHave)
  callsigns = logHash.keys.sort { |x,y| logHash[y] <=> logHash[x] }
  callsigns = (callsigns.to_set - alreadyHave).to_a
  callsigns[0..8].reduce("") { |total, callsign|
    if total.length == 0
      comma = ""
    else
      comma = ", " 
    end
    total = total + comma + callsign + "(" + logHash[callsign].to_s + ")"
  }
end

def multiplierData(db, counties, states, potentialLogs)
  aliases = Hash.new
  CSV.open(File.dirname(__FILE__) + "/../multipliers.csv", "r:ascii") { |io|
    io.each { |line|
      if line[1] != "XXXX"
        aliases[line[0]] = line[1]
        if 2 == line[1].length
          states[line[1]] = Set.new
        elsif 4 == line[1].length
          counties[line[1]] = Set.new
        end
        if not potentialLogs.has_key?(line[1])
          potentialLogs[line[1]] = Hash.new(0)
        end
      end
    }
  }
  ids = db.allEntries
  ids.each { |id|
    allInfo = db.getEntry(id)
    if allInfo and 1 == allInfo["completed"] and allInfo["sentqth"]
      sentq = scanQSOs(allInfo["asciifile"], aliases, potentialLogs)
      if aliases.has_key?(allInfo["sentqth"])
        loc = aliases[allInfo["sentqth"]]
      elsif aliases.has_key?(sentq)
        loc = aliases[sentq]
      else 
        loc= nil
      end
      if loc
        if 4 == loc.length
          counties[loc].add(callBase(allInfo["callsign_confirm"].upcase.strip))
        else
          states[loc].add(callBase(allInfo["callsign_confirm"].upcase.strip))
        end
      end
    end
  }
end

def multiplierText(counties, states, potentialLogs)
  count = 0
  return "<table %{tablestyle}>
<caption %{capstyle}>CQP %{year} Completed Logs for Each Multiplier</caption>
<tr>
  <th %{headeven}>Multiplier</th><th %{headeven}># Logs</th><th %{headeven}>Potential logs</th>
</tr>
" + counties.keys.sort.reduce("") { |total, loc|
   count = count + 1
   if count.even?
     total = total + "<tr><td %{dataeven}>" + loc + "</td><td %{dataeven}>" + counties[loc].length.to_s + "</td><td %{dataeven}>"+ bigLogs(potentialLogs[loc], counties[loc]) +"</td></tr>\n"
   else
     total = total + "<tr><td %{dataodd}>" + loc + "</td><td %{dataodd}>" + counties[loc].length.to_s + "</td><td %{dataodd}>"+bigLogs(potentialLogs[loc], counties[loc]) +"</td></tr>"
   end
  } + states.keys.sort.reduce("") { |total, loc|
    count = count + 1
    if count.even?
      total = total + "<tr><td %{dataeven}>" + loc + "</td><td %{dataeven}>" + states[loc].length.to_s + "</td><td %{dataeven}>"+bigLogs(potentialLogs[loc], states[loc]) + "</td></tr>\n"
    else
      total = total + "<tr><td %{dataodd}>" + loc + "</td><td %{dataodd}>" + states[loc].length.to_s + "</td><td %{dataodd}>" + bigLogs(potentialLogs[loc], states[loc]) + "</td></tr>"
    end
  } + "</table>\n\n"
end

def multiplierTable(db)
  potentialLogs = Hash.new
  states = Hash.new
  counties = Hash.new
  multiplierData(db, counties, states, potentialLogs)
  return multiplierText(counties, states, potentialLogs)
end
