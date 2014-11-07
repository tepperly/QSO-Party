#!/usr/bin/env ruby
# -*- encoding: utf-8; -*-
#
# Based on prior work by Matt WX%S, N6KO and WB6S
#

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
  else                          # more than 3 who knows
    parts.sort! { |x,y|
      compareCallParts(x,y)
    }
    parts[-1]
  end
end
