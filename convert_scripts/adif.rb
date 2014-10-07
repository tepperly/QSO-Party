#!/usr/bin/env ruby
# ADIF module
# by Tom Epperly
# ns6t@arrl.net

require 'date'

class ClockTime

  def initialize(hours, minutes, seconds=0)
    @hours = hours
    @minutes = minutes
    @seconds = seconds
  end
  attr_reader :hours, :minutes, :seconds
  def to_s
    return ("%02d" % @hours) + ":" + ("%02d" % @minutes) + ":" + ("%02d" % @seconds)
  end

  def <=>(rhs)
    if hours == rhs.hours
      if minutes == rhs.minutes
        seconds <=> rhs.seconds
      else
        minutes <=> rhs.minutes
      end
    else
      hours <=> rhs.hours
    end
  end
end

class Token
  def initialize(name, text, value, type)
    @name = name
    @text = text
    @value = value
    @type = type
  end

  attr_reader :name, :text, :value, :type
end

def min(x,y)
  if x < y 
    x
  else
    y
  end
end
  

def nextToken(io)
  # Ignore everything until next < character
  while (c = io.read(1) and (c != '<'))
  end
  if (c)
    name, text, value, type = readToken(io)
    if (name)
      return Token.new(name, text, value, type)
    end
  end
  return nil
end

NATURAL_REGEX = /^[0-9]+$/
FLOAT_REGEX = /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/
LOCATION_REGEX = /^([NEWSnews])(\d{3,3})\s+(\d{2,2}\.\d{3,3})$/
TOKEN_TYPES = {
  'address' => 'm',
  'age' => 'n',
  'arrl_sect' => 'c',
  'band' => 'c',
  'call' => 'c',
  'cnty' => 'c',
  'comment' => 'c',
  'cont' => 'c',
  'contest_id' => 'c',
  'cqz' => 'n',
  'dxcc' => 'n',
  'freq' => 'n',
  'gridsquare' => 'c',
  'iota' => 'c',
  'ituz' => 'n',
  'lat' => 'l',
  'lon' => 'l',
  'mode' => 'c',
  'my_lat' => 'l',
  'my_lon' => 'l',
  'name' => 'c',
  'notes' => 'm',
  'operator' => 'c',
  'pfx' => 'c',
  'prop_mode' => 'c',
  'qslmsg' => 'm',
  'qslrdate' => 'd',
  'qslsdate' => 'd',
  'qsl_rcvd' => 'c',
  'qsl_sent' => 'c',
  'qsl_via' => 'c',
  'qso_date' => 'd',
  'qth' => 'c',
  'rst_rcvd'=> 'c',
  'rst_sent'=> 'c',
  'rx_pwr' => 'n',
  'sat_mode' => 'c',
  'sat_name' => 'c',
  'srx' => 'n',
  'state' => 'c',
  'stx' => 'n',
  'ten_ten' => 'n',
  'time_off' => 't',
  'time_on' => 't',
  'tx_pwr' => 'n',
  've_prov' => 'c'
}
TOKEN_TYPES.default = 'c'

def readString(io, length)
  result = ""
  while ((length > 0) and (c = io.getc)) 
    if c.is_a?(Numeric)
      c = c.chr
    end
    if (c == "\r")
      n = io.getc
      if n.is_a?(Numeric)
        n = n.chr
      end
      if (n == "\n")
        result = result + n
        length = length - 1
      else
        if (length > 1)
          result = result + c + n
          length = length - 2
        else
          result = result + c
          length = length - 1
          io.ungetc(n)
        end
      end
    else
      result = result + c
      length = length - 1
    end
  end
  return result
end


def readToken(io)
  name = ""
  while (c = io.read(1) and (c != ':') and (c != '>'))
    name = name + c
  end
  name.downcase!
  if c == ">"
    return name, nil, nil, nil
  elsif c == ':'
    length = ""
    while (c = io.read(1) and ((c >= '0') and (c <= '9')))
      length = length + c
    end
    if (c == ':')
      type = io.read(1)
      type.downcase!
      c = io.read(1)
    else
      type = TOKEN_TYPES[name]
    end
    if (c == '>')
      length = length.to_i
      text = readString(io, length)
      if ((type == 'd') and (length == 8))
        value = Date.new(text[0,4].to_i, text[4,2].to_i, text[6,2].to_i)
      elsif (type == 't')
        if (length == 4)
          value = ClockTime.new(text[0,2].to_i, text[2,2].to_i)
        elsif (length == 6)
          value = ClockTime.new(text[0,2].to_i, text[2,2].to_i, text[4,2].to_i)
        else
          value = nil
        end
      elsif ((type == 'n') and (text =~ NATURAL_REGEX))
        value = text.to_i
      elsif ((type == 'n') and (text =~ FLOAT_REGEX))
        value = text.to_f
      elsif ((type == 'l') and (text =~ LOCATION_REGEX))
        value = [ $1.upcase, $2.to_f + $3.to_f/60.0 ]
      else
        value = text
      end
      return name, text, value, type
    end
  end
  return nil, nil, nil, nil
end

def capall(str)
  str.split.map(&:capitalize).join(' ')
end


class QSO
  def initialize
    @texts = Hash.new
    @values = Hash.new
  end

  def addAttr(name, text, value)
    name = name.downcase
    @texts[name] = text
    @values[name] = value
  end

  def operator
    @texts["operator"]
  end

  def getText(key)
    @texts[key]
  end

  def getValue(key)
    @values[key]
  end

  def station_callsign
    if @texts.has_key?("station_callsign")
      @texts["station_callsign"]
    else
      if @texts.has_key?("operator")
        @texts["operator"]
      else
        @texts["owner_callsign"]
      end
    end
  end

  def band
    @values["band"]
  end

  def state
    @values["state"]
  end

  def county
    if @values.has_key?("cnty")
      capall(@values["cnty"].gsub(/^[^,]*,/,""))
    else
      nil
    end
  end

  def iota
    @texts["iota"]
  end

  def qso_date
    @values["qso_date"]
  end

  def call
    @texts["call"]
  end

  def worked
    call
  end

  def <=>(rhs)
    if worked == rhs.worked
      if qso_date == rhs.qso_date
        qso_time <=> rhs.qso_time
      else
        qso_date <=> rhs.qso_date
      end
    else
      worked <=> rhs.worked
    end
  end

  def has_key?(key)
    @texts.has_key?(key)
  end

  def combinable?(other)
    (station_callsign == other.station_callsign) and (call == rhs.call)
  end

  def qso_time
    @values["time_on"]
  end

  def frequency
    @texts["freq"]
  end

  def via
    @texts["qsl_via"]
  end

  def mode
    @texts["mode"]
  end

  def report
    @texts["rst_sent"]
  end

  def address
    @texts["address"]
  end

  def cqz
    @values["cqz"]
  end

  def ituz
    @values["ituz"]
  end

  def gridsquare
    @texts["gridsquare"]
  end

  def latlong
    if @texts.has_key?("lat") and @texts.has_key("lon")
      latitude = @values["lat"][1]
      if @values["lat"][0] == "S"
        latitude = -latitude
      end
      longitude = @values["lon"][1]
      if @values["lon"][0] == "W"
        longitude = -longitude
      end
      [ latitude, longitude ]
    else 
      nil
    end
  end

  def lotw?
    @texts.has_key?("lotw_qsl_rcvd") and ((@texts["lotw_qsl_rcvd"].upcase == "Y") or
                                          (@texts["lotw_qsl_rcvd"].upcase == "V"))
  end

  def eqsl?
    @texts.has_key?("eqsl_qsl_rcvd") and ((@texts["eqsl_qsl_rcvd"].upcase == "Y") or
                                          (@texts["eqsl_qsl_rcvd"].upcase == "V"))
  end

  def qsl?
    @texts.has_key?("qsl_rcvd") and ((@texts["qsl_rcvd"].upcase == "Y") or
                                     (@texts["qsl_rcvd"].upcase == "V"))
  end

  def to_s
    result = ""
    @texts.each { |key,value|
      if 'm' == TOKEN_TYPES[key]
        value = value.gsub(/\r([^\n]|\z)/, "\r\n"'\1')
        value = value.gsub(/([^\r])\n/, '\1'"\r\n")
      end
      result += "<" + key + ":" + value.to_s.length.to_s + ">" + value.to_s
    }
    result + "\n<eor>\n"
  end
end

def parseFile(io, qsos)
  headerFinished = nil
  qso = nil
  while (tok = nextToken(io))
    if (headerFinished)
      if tok.name == "eoh"
        print "Unexpected eoh item at line " + io.lineno.to_s + "\n"
      elsif tok.name == "eor"
        qsos.push(qso)
        qso = nil
      else
        if nil == qso 
          qso = QSO.new
        end
        qso.addAttr(tok.name, tok.text, tok.value)
      end
    else
      if tok.name == "eoh"
        headerFinished = true
        qso = nil
      end
    end
  end
  if qso
    qsos.push(qso)
  end

end

def compress(list)
  result = [ ]
  item = [ ]
  list.each { |q|
    if item.empty?
      item << q
    else
      prev = item.last
      if (prev.call == q.call) and (prev.station_callsign == q.station_callsign)
        item << q
        if item.length >= 4
          result << item
          item = [ ]
        end
      else
        result << item
        item = [ q ]
      end
    end
  }
  if not item.empty?
    result << item
  end
  result
end
