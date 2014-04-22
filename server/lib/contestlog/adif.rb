# Module for generating/reading ADIF log files
# 
# Author:: N6RNO
# License::  &copy; 2014 Northern California Contest Club
#            2-Clause BSD License
#
# Version:: 1.0-0.1
#      Major/minor version number tied to ADIF specification
#      Versions of ADIF are upwards compatible... ADIF 2.3 reader can read ADIF 1.0
#      Starting with ADIF 3.0 there is now a true XML version of the format
#        *.adi is ASCII format and *.adx is UTF-8 XML
#
#
# Based in part on:
#      Format information and samples at: http://adif.org
#


require 'contestlog/genericlog'
require 'pp'

class Adif < Genericlog
#
# There are a few interesting "gotcha's" in the specification
# 
#    1) If the first character in the file is not '<'  (less than) then all text is
#        header information until '<eoh>' is found. Header information is 
#        completely free format. There are no rules. Each implementation
#        is completely free to put any or no information in the header.
#        This generally make ADIF a poor choice for contest log submission
#        as contest groups need some information that the  fields
#        of ADIF do not provide. It is suggested that the field tag <adif_ver:4>1.00
#        be used to indicate the Version of ADIF that a log is written to.
#
#    2) The field length as specified in a tag is technically very important.
#        After that length, all other characters are meaningless until the 
#        next '<' character. Effectively you can write comments within the 
#        output and all compliant tools are supposed to work with this.
#        In practice you should not take advantage of this "feature" as 
#        most programmer's will miss this subtlety.
#        The field length is required and can not be negative. The 
#        specification allows the length to be 0.  
#
#    3) Field names are case insensitive and the field type is optional.
#
#     4) Applications are free to extend the specification by adding their
#         own application specific fields. Import applications are to ignore
#         any fields that they do not understand. (Actually, they probably
#         should issue an informational message about such unhandled
#        fields. But it's programmers choice. They are required by the 
#         specification to be tolerant of such fields)
#


# Information from the Specification
#  3. Field Definitions:
#
# Name        Type  Comment
# ADDRESS   M As it will appear on the mailing label
# AGE     N  
# ARRL_SECT C  
# BAND      C 160M, 80M, 40M, 30M, 20M, 17M, 15M, 12M, 10M, 6M, 2M, 70CM,23CM...see table below
# CALL      C  
# CNTY      C US County in the format STATE,COUNTY. For example GA,BARROW. Use CQ County list
# COMMENT C Comment field for QSO
# CONT      C Continent: NA,SA,EU,AF,OC,AS
# CONTEST_ID  C Contest Indentifier -- SS, ARRLVHF, ARRLDX, etc.
# CQZ     N CQ Zone
# DXCC      N Numeric identifiers from ARRL. See table below
# FREQ      N in Megahertz
# GRIDSQUARE  C 4, 6, or 8 or however many characters
# IOTA      C HYPHEN MUST BE INCLUDED. Example: NA-001 IOTA PROVIDES DISK IN THIS FORMAT
# ITUZ      N ITU Zone
# MODE    C SSB, CW, RTTY, TOR=AMTOR, PKT, AM, FM, SSTV, ATV, PAC=PACTOR,CLO=CLOVER
# NAME    C  
# NOTES   M Long text for digital copy, third party traffic, etc.
# OPERATOR  C Callsign of person logging the QSO
# PFX     C WPX prefix
# PROP_MODE C  
# QSLMSG    M Personal message to appear on qsl card
# QSLRDATE  D QSL Rcvd Date
# QSLSDATE  D QSL Sent Date
# QSL_RCVD  C Y=Yes, N=No, R=Requested, I=Ignore or Invalid
# QSL_SENT  C Y=Yes, N=No, R=Requested, I=Ignore or Invalid
# QSL_VIA   C  
# QSO_DATE  D YYYYMMDD in UTC
# QTH     C  
# RST_RCVD  C  
# RST_SENT  C  
# RX_PWR    N Power of other station in Watts
# SAT_MODE  C Satellite Mode
# SAT_NAME  C Name of satellite
# SRX     N Received serial number for a contest QSO
# STATE   C US state
# STX     N Transmitted serial number for a contest QSO
# TEN_TEN   N  
# TIME_OFF  C HHMM or HHMMSS in UTC
# TIME_ON   C HHMM or HHMMSS in UTC
# TX_PWR    N Power of this station in watts
# VE_PROV   C 2-letter abbreviations: AB, BC, MB, NB, NF, NS, NT, ON, PE, QC, SK, YT
#
#Band designations:
#    HF frequencies are not in standard and are taken from Cabrillo spec
#   Band    Frequency
# 160m    1800
# 80m     3500
# 40m     7000
# 30m  
# 20m     14000
# 17m 
# 15m     21000
# 12m  
# 10m     28000
# 6m      50
# 2m      144
# 1.25m   220
# 70cm    432
# 35cm    902
# 23cm    1300
# 13cm    2300
# 9cm     3300
# 6cm     5660
# 3cm     10000
# 1.25cm    24000
# 6mm   47 GHz
# 4mm   75
# 2.5mm   120
# 2mm   142
# 1mm     241
# 
#

  class IllegalFormatError < RuntimeError; end
  
  def qsos
    @qso
  end
  
  def headers
    @head_info
  end
  
  def initialize(fn,mode='r',purpose=nil)
    log = super(fn,mode)

    if mode == 'r'
      #
      # Deal with reading / translation issues
      #
      if log.type_is?('ADIF')
        @qso = []  # ADIF qso's record start at first character of file or <eoh> if first character is not <
                 #     each record ends with <eor>  or EOF for the last record.
                 #   Tags are case insensitive and follow format  <tag:fieldType:length>
        @head_info = ''   # ADIF headers are an arbitrary collection of text
         # ADIF format is really too flexible so we have to treat the entire file as a string of characters
        adif_header { |h| @head_info=h }  #one-shot iterator due to nature of adif
        adif_records do |r|
          # gather the individual ADIF records and parse into a hash
          fields = {}
          adif_fields(r) do |k,v|
            fields[k] = v
          end
          @qso.push fields
        end
        # now just a little clean up ... should be empty anyway
        @data.compact
      end
    end
  end
  
  #
    #     ADIF stuff .... re-factor to adif.rb
    #
    #      ADIF files consist of header section (optional) ending with <eoh>
    #

  #  
  # <PROGRAMID:14>HamRadioDeluxe
  # <PROGRAMVERSION:26>Version 4.0 SP4 build 1901
  #
  
  def program_id(s)
    # figure out the program id in an open ADIF file
    #     This is an extension to ADIF
    #  We will completely cheat for now.
    #
    'Ham Radio Deluxe'
  end
  
  def program_version(s)
    # find the version of the program that created the log
    #    This is an extension to ADIF
    # We will completely cheat
  end
  
  private
  # special iterators for use in initialize (hides details of how to read data[]

  def adif_header
    h = ''
    if block_given?
      if @data[0] =~ /^</
        yield nil
      else
        #consume @data until we find <eoh>
        until (@data[0] =~ /<eoh>/i) do
          h << @data.shift
        end
        #  remove everything until <eoh> and upto but not including next <
        @data[0].sub!(/^(.*)<eoh>[^<]*/i) do
          if defined? $1
            h << $1
          end
          '' #delete, potentially the entire @data[0]
        end

        if @data[0].length == 0
          @data.shift   # clear a null entry
        end
        yield h
        
      end
    else
      self.to_enum(:adif_header)
    end
  end

  def adif_records
    
    if block_given?
      until @data.count == 0
        r = ''
        #consume @data until we find <eor>
        until (@data[0] =~ /<eor>/i) do
          r << @data.shift
        end
        #  remove everything until <eoh> and upto but not including next <
        @data[0].sub!(/^(.*)<eor>[^<]*/i) do
          if defined? $1
            r << $1
          end
          '' #delete, potentially the entire @data[0]
        end

        if @data[0].length == 0
          @data.shift   # clear a null entry
        end
        yield r
        
      end
    else
      self.to_enum(:adif_records)
    end
  end

  def adif_fields(r)
    
    if block_given?
      until r.length == 0
        key = ''
        value = ''
        format = ''
        len = 0
        r.sub!(/^[^<]*/m,'') #consume to start of next field tag
        r.sub!(/^<([^:>]+):([\d+]+)(:((D(A(T(E)?)?)?)|(T(I(M(E)?)?)?)|(M)|(C)))?>/i) do
          #  format is optional (and for now we ignore)
          #   1 => tag, 2 => length, 3=> format
          key = $1
          len = $2
          ''
        end
        r.sub!(/^(.{#{len}})/) do
          value = $1
          ''
        end
        
        yield(key,value)
        
      end
    else
      self.to_enum(:adif_fields)
    end
  end

end

__END__

    when /^(ADIF\s+file)\s*\r?\n([^\r\n]*)\r?\n/m
      lm = Regexp.last_match
      @logger = lm[2].gsub(/^\s+/,'').gsub(/ on .*/,'')
      @ftype = "ADIF %s" % @logger
    when /^ADIF\s+(Export from)\s+(\S+)/ || /^<(ADIF_VERS?):\d>(\S+)/ 
      lm = Regexp.last_match
      @logger = lm[2]    # warn hacky, if ADIF_VERS matches then lm[1] is the ADIF VERSION
      @ftype = "ADIF %s" % lm[2]
  
