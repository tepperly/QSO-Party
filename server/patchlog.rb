#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP upload script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

def makePatch(attributes)
  result = "".encode("US-ASCII")
  attributes.each { |key, value|
    keystr = key.upcase.strip.encode("US-ASCII") + ": " 
    if value =~ /(\r?\n)/       # multi-line value string
      value.split(/(\r?\n)/).each { |line|
        result = result + keystr + line.strip.encode("US-ASCII", :invalid => :replace,
                                                           :undef => :replace) + "\n"
      }
    else
      result = result + keystr + value.strip.encode("US-ASCII", :invalid => :replace,
                                                           :undef => :replace) + "\n"
    end
  }
  result
end

def findConvenientLocation(content)
  # first choice is right before the first QSO
  loc = content.index(/^\s*QSO\s*:/i)
  if not loc
    # second choice is before any legitimate Cabrillo header item
    loc = content.index(/^\s*(LOCATION|CALLSIGN|CATEGORY-OPERATOR|CATEGORY-ASSISTED|CATEGORY-POWER|CATEGORY-TRANSMITTER|CLAIMED-SCORE|CLUB|CONTEST|CREATED-BY|NAME|ADDRESS|ADDRESS-CITY|ADDRESS-STATE-PROVINCE|ADDRESS-POSTALCODE|ADDRESS-COUNTRY|OPERATORS|SOAPBOX|EMAIL|OFFTIME|CATEGORY)\s*:/i)
  end
  loc
end

def patchLog(content, attributes)
  content.gsub!(/\r\n/, "\n".encode("US-ASCII"))   # standardize on Linux EOL standard
  patch = makePatch(attributes)
  firstQ = findConvenientLocation(content)
  if firstQ                     # insert patch right before first QSO
    content = content.insert(firstQ, patch)
  end
  content
end

def makeAttributes(id, callsign, email, email_confirm, sentqth, phone, comments,
                   expedition, youth, mobile, female, school, newcontester,
                   clubname, clubother, clubcategory)
  result = { }
  result['X-CQP-CALLSIGN'] = callsign
  result['X-CQP-SENTQTH'] = sentqth
  result['X-CQP-EMAIL'] = email
  result['X-CQP-CONFIRM1'] = email_confirm
  result['X-CQP-PHONE'] = phone
  result['X-CQP-COMMENTS'] = comments
  categories = [ ]
  if expedition == 1
    categories.push("COUNTY")
  end
  if youth == 1
    categories.push("YOUTH")
  end
  if mobile == 1
    categories.push("MOBILE")
  end
  if female == 1
    categories.push("YL")
  end
  if school == 1
    categories.push("SCHOOL")
  end
  if newcontester == 1
    categories.push("NEW_CONTESTER")
  end
  if clubname and (not clubname.strip.empty?) and "OTHER" != clubname
    result['X-CQP-CLUBNAME'] = clubname.strip.upcase
  else
    if clubother and (not clubother.strip.empty?)
      result['X-CQP-CLUBNAME'] = clubother.strip.upcase
    end
  end
  if clubcategory and (not clubcategory.strip.empty?)
    result['X-CQP-CLUBCATEGORY'] = clubcategory.strip.upcase
  end
  result['X-CQP-CATEGORIES'] = categories.join(" ")
  result['X-CQP-ID'] = id.to_s
  result['X-CQP-TIMESTAMP'] = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S.%L +0000")
  result
end
