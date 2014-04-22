# encoding: UTF-8
# Module for generating/reading generic contest log files
#
# Author:: N6RNO
#
# License::  &copy; 2014 Northern California Contest Club
#            2-Clause BSD License
#
# This module can identify many different possible file formats
# that a user may attempt to submit to a contest. Most of these
# formats are not permitted by contest sponsors.
# There is no attempt in this module to convert any log format
# to any other format.
#
# It is expected that a file will first be opened by this module
# so that it can be identified and then further processed by
# supported subclasses like Cabrillo or Adif
#

class Genericlog

  # known_log_types::
  # Cabrillo ADIF CQPWIN CQPDOS CT Excel Zip ASCII Raw Raw_Cabrillo Raw_ADIF
  # PDF RTF CSV Unknown
  #

  public

  # file name for reading/writing
  attr_accessor :name
  # binary string for binary files and array for text files
  attr_accessor :data
   # list of files found in an archive along with their type
  attr_reader :files
  # specific coding of file.  Defined values:  Cabrillo, ADIF, CQPWIN, CQPDOS, Excel, zip, PDF, RTF, XML, binary, ASCII, PRINTER_CODE
  attr_accessor :coding 
  
  # do we need special "style_is"?
  def style_is
    @coding
  end
  
  def style_is?(fmt)
    @coding === fmt
  end
  
  def style=(fmt)
    @coding = fmt
  end
  
  # clears internal attributes of the class
  def clear
    @name = nil
    @coding = :unknown
    @data = []
    @files = []
  end
  
  # clears internal attributes of the class
  alias init clear
  
  private
  
  #
  # == Private Special regexp for contests
  #
  # m3e:: 3 letter months
  # be:: band/frequency   160m-2m
  #
  @@m3e = 'JAN|FEB|MA(R|Y)|APR||JU(N|L)|AUG|SEP|OCT|NOV|DEC'
  
  @@b1e = '(((16|[8421])0|15|[62])[mM]?)'
    # frequency set is incomplete ... only 160 to 10m ....
  @@b2e = '(([137]|14|21|28)\d{4})'
  @@be = "(#{@b1e}|#{@b2e}"
    
  @@me = 'CW|PH|SSB|USB|LSB|RTTY'
  @@de = "(\d{4}|\d{1,2}|(#{@m3e}))[-\/]((#{@m3e})|\d{1,2})|[-\/](\d{1,2}|\d{4})"
  
  # Make educated guess as to the file type by looking at the contents.
  # We cannot trust the extension. And in the case of zip archives we can not even
  # trust the first few bytes. Microsoft Office 2007 files are zip archives.
  #
  # OPTIMIZE: We should consider re-factoring this into a more general solution.
  # There are programs like Unix file, TrID (by Marco Pontello <mailto:marcopon@gmail.com>)
  # that already identify file types by content. These programs use external configuration files
  # so that they are extensible. In our application we do not need that much extendibility, we
  # operate in the limited domain of amateur radio contests and should see a very limited set of
  # files.
  def filecoding(line,fn)
    case line
    when /^START-OF-LOG:\s+[vV]?[23](\.[0-9])?/i 
      :Cabrillo
    when Regexp.new('^\xef\xbb\xbfSTART-OF-LOG:\s+[vV]?[23](\.[0-9])?',Regexp::IGNORECASE,'n')
      # some versions of N3FJP add 3 >128 characters to the first line... otherwise the file seems fine
      line.sub!(/.../,'')
      :Cabrillo
    when /<(eoh|eor)>/mi 
      :ADIF
    when /^ADIF/i
      :ADIF
    when /^<[^:]+:\d+>/
      :ADIF
    when /^<\?xml.*\r\n\s*<ADX>/mi
      :ADX
    when /^%PDF/
      :PDF
    when /^\{\\rtf/
      :RTF
    when /^QSO:/i
      :CabrilloQSOonly
    when /^\[REG1TEST;1\]/
      # Region 1 Contest: IARU for > 30MHz
      #  http://vkvzavody.moravany.com/EDI.TXT
      :REG1TEST
    when /^\d{1,2}\/\d{1,2}\/\d{1,2}\s+/
      :RawLogDateFirst
      
      
    # careful Office 2007 files seem to be ZIP archives that hold Open XML files
    # All Office 2007 "x" format files have the following pattern
    #
    # from IRB after IO.binread
    #   PK\x03\x04\x14\x00\b\b\b\x00!z\x96D
    #
    # And OpenDocument Format can also be in an archive
    #   need to do research to know the files that are indicative 
    #   of ODF
    #
    # from IRB after IO.binread
    #   PK\x03\x04\x14\x00\x00\b\x00\x00/z\x96D\x85l9\x8A.\x00\x00
    #
    #   Ruby 1.9.3 has issue with \b aka \x08
  
    when Regexp.new('^PK\x03\x04\x14\x00\x00\x08',nil,'n')
      :ODS
    when Regexp.new('^PK\x03\x04\x14\x00\x08\x08',nil,'n')
      :EXCEL
      
    when /^PK/
      :ZIP
      
    when Regexp.new('^(\x00{4}\x01)',nil,'n') 
      # By AE6Y
      :CQPWIN
    when /^\x00{6} {10}/ && /^.{20}CQPIN/
      # this test is hacked ... if you add %% /^.{20}CQPIN to CQPWIN test then this test is never found
      :CQPDOS
    
    # Generic MS-Office file Multi-Stream Object Header   D0 CF 11 E0 A1 B1 1A E1
    when Regexp.new('^\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1\x00',nil,'n')
      :EXCEL
    #when /^\s*(#{@de}|#{@me}|#{@be}\s+){1,3}/
    # @ftype="ASCII log"
    when Regexp.new('^\x1B\x43\x00\f',nil,'n')
      #   ESC C NUL FF   <- EPSON printer code to set page length
      :PrinterCode
    when /^[A-Z0-9 .-:\/]*,[A-Z0-9 .-:\/]*,[A-Z0-9 .-:\/]*,[A-Z0-9 .-:\/]*/i
      :CSV
    when /^[ -~\n\t\r\f]+$/  #catchall test for ASCII file This must be last one checked
      :ASCII
    when Regexp.new('^\x52\x61\x72\x21\x1A',nil,'n')
      # Rar!      
      # RAR Archive
      :RAR
    when Regexp.new('^\x1F\x8b\x08',nil,'n')
      # GZIP file
      :GZIP
    when Regexp.new('^..\x00\x00\x47\x5A\x49\x50',nil,'n')
      # ....GZIP
      # GZIP compressed archive
      :GZA
    when /^\?xml\s+/
      # General XML file (ADIF 3.0 looks like this)
      :XML
    else 
      #
      #   If we get here then it's some binary file that we do not know about
      #
        #print fn, ':',@data[0].unpack("AAAAAAAAAAA")," Hex:",@data[0].unpack("H2 H2 H2 H2 H2 H2 H2 H2 H2"),"\n"
      :binary
    end
  end
  
  public
  
  # read log file, extract entire file into @data
  # also determine the type of the file just read.
  # Note: Binary files will read into @data in an unpredictable way. We probably so recode the binary reads to be more predictable.
  def read(file_name=nil)
    puts file_name
    unless file_name.nil?
      head = IO.binread(file_name,2048)
      @coding = filecoding(head,file_name)
      case @coding
      when :Cabrillo,:ADIF,:CabrilloQSOonly,:CSV,:REG1TEST,:ASCII
        IO.foreach(file_name) {|line| @data.push(line) }
      end
    end
  end

  # read log file from a zip file, extract just the same as if we used read
  def read_zip(file_name=nil,entry=nil)
    @files = []
    if !(file_name.nil? || entry.nil?)
      #puts "Open zipfile #{file_name} file #{entry}"
      @data = Zip::ZipFile.open(file_name).read(entry)
      @coding = filecoding(@data,"#{file_name}(#{entry})")
    end
  end
  
  def initialize
    init
  end
  # new is heavy handed when mode is :r and a file name is provided.
  # the entire file is read into the *data*. When file coding is an ASCII readable form then
  # *data* is an array of the lines in the specified file.
  # When the coding is a binary form such as Excel or CQPWIN, then *data* holds a binary String
  # of the contents of the file.
  def initialize(file_name=nil,mode=:rb,type=:unknown)
    init
    @name = Pathname.new(file_name).basename.to_s if file_name
    self.read(file_name)
  end
  
# You can get the main FFC call database from: 
#
#   http://wireless.fcc.gov/uls/data/complete/l_amat.zip
#
# The daily data bases are available as a set of seven from here
#
#   http://wireless.fcc.gov/uls/data/daily/l_am_sat.zip 
#   http://wireless.fcc.gov/uls/data/daily/l_am_sun.zip 
#   http://wireless.fcc.gov/uls/data/daily/l_am_mon.zip 
#   http://wireless.fcc.gov/uls/data/daily/l_am_tue.zip 
#   http://wireless.fcc.gov/uls/data/daily/l_am_wed.zip 
#   http://wireless.fcc.gov/uls/data/daily/l_am_thu.zip 
#   http://wireless.fcc.gov/uls/data/daily/l_am_fri.zip
#

end