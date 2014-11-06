#!/usr/bin/env ruby
# -*- encoding: utf-8; -*-
require_relative 'callsign'

TESTCASES = [
  # result, input
  [ "F6ABC", "f6abc/" ],
  [ "F6ABC", "f6abc" ],
  [ "G3ABC", "G3abc/w4" ],
  [ "G3ABC", "w4/g3abc" ],
  [ "WX5S", "Kp2/WX5S" ],
  [ "WX5S", "wx5s" ],
  [ "WX5S", "WX5S/6" ],
  [ "WX5S", "WX5S /6" ],
  [ "WX5S", "WX5 s" ],
  [ "WX5S", "wx5s/qrp" ],
  [ "WX5S", "wx5s/dl" ],
  [ "WX5S", "WX5s/dl0" ],
  [ "WX5S", "dl/wx5s" ],
  [ "WX5S", "dl9/wx5s" ],
  [ "WX5S", "DL7/wx5s/mm2" ],
  [ "WX5S", "DL7/  wx5s/mm2" ],
  [ "W3ABC", "4m7/w3abc" ],
  [ "W3ABC", "4m7/w3abc/qrp" ],
  [ "W6YX", "W6YX/WX5S" ],
  [ "W6OAT", "W6OAT/yuba" ],
  [ "W6OAT", "Yuba/W6oat" ],
  [ "3B8CF", "4m7/3B8CF" ],
  [ "3B8CF", "3B8CF/4M7" ],
  [ "WA6O", "WA6O/YUBA" ],
  [ "3B8CF", "3B8CF/mm" ],
  [ "3B8CF", "DL/3B8CF/mm/QRP" ],
  [ "WABC", "dl/wabc" ],
  [ "WABC", "dl/wabc/qrp" ],
  [ "WABC", "3b8/wabc" ],
  [ "WABC", "ve/wabc" ],
  [ "DL0ABC", "ve3/DL0ABC" ],
  [ "WX5S", "qrp/wx5s" ],
  [ "N6O", "N6O/qrp" ],
  [ "JA3ABC", "9v1/ja3abc/mm" ],
  [ "WABC", "ve8/wabc" ],
  [ "WABC", "wabc/7" ],
  [ "W7]=BC", "w7]=bc/ve8" ],
  [ "Q5P", "wabc/q5p" ],    ## wrong should be WABC
  [ "QRP", "wabc/qrp" ],    ## wrong should be WABC
  [ "WABC", "wabc/mm/qrp" ],
  [ "YUBA", "WA61/YUBA" ],  ## wrong should be WA61
  [ "WA61X", "WA61X/YUBA" ],
  [ "W3ABC", "w3abc/4m7" ],
  [ "VE1RGB", "cy0/ve1rgb" ],
  [ "CY0A", "Cy0a" ]]

TESTCASES.each { |test|
  if test[0] != callBase(test[1])
    print "callBase(\"#{test[1]}\") => \"#{callBase(test[1])}\" *NOT* \"#{test[0]}\"\n"
  end
}
