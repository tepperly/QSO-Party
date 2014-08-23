#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# CQP log scan script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

def logProperties(str)
  results = { }
  results["QSOlines"] = str.scan(/\bqso:\s+/).size
  
  results
end
