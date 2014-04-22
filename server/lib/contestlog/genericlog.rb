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
    when /^\xef\xbb\xbfSTART-OF-LOG:\s+[vV]?[23](\.[0-9])?/i 
      # some versions of N3FJP add 3 >128 characters to the first line... otherwise the file seems fine
      line.sub!(/.../,'')
      :Cabrillo
    when /<(eoh|eor)>/mi 
      :ADIF
    when /^ADIF/i
      :ADIF
    when /^<[^:]+:\d+>/
      :ADIF
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
    #   @0 -> 504B0304
    #             PK
    #   @30 -> 5B436F6E74656E745F54797065735D2E786D6C
    #               [ C o n t e n t _ T y p e s ] . x m l
    # else where in the directory you will find the following files
    #   APP.XMLPK 
    #   DOCPROPS 
    #   CORE.XMLPK 
    #   THEME1.XMLPK ?
    #   _RELS 
    #
    # - DOCX will have the following files
    #   DOCUMENT.XML.RELSPK 
    #   DOCUMENT.XMLPK 
    #   FONTTABLE 
    #   STYLES 
    #   WORD 
    #
    # - XLSX will have the following files
    #   WORKBOOK.XML.RELSPK 
    #   WORKBOOK.XMLPK 
    #   STYLES.XMLPK 
    #   SHEET1.XMLPK 

    #   WORKSHEETS 
    #
    # - PPTX will have the following file patterns
    # PRESENTATION.XMLPK 
    # SLIDEMASTER1.XMLPK 
    # SLIDELAYOUT1.XMLPK 
    # TABLESTYLES.XMLPK 
    # SLIDE1.XML.RELSPK 
    # VIEWPROPS.XMLPK 
    # PRESPROPS.XMLPK 
    # SLIDEMASTERS 
    # SLIDE1.XMLPK 
    # SLIDELAYOUTS 
    # SLIDES 

    # And OpenDocument Format can also be in an archive
        #   need to do research to know the files that are indicative 
    #   of ODF
    
    when /^PK/
      
      openFormat = nil
      
      Zip::ZipFile.open(fn) {|zipfile|
        # if we take the time to read in a little bit of all the files in the zip archive we can help
        # the user by identifying the type. 
        
        Zip::ZipFile.foreach(fn) {|entry|
          # Be on the lookout for Office 2007
          case entry.name
            when  /WORKBOOK\.XMLPK/
              openFormat = :Excel2007
              break
            when /DOCUMENT\.XMLPK/
              openFormat = :Word2007
              break
            when /PRESENTATION\.XMLPK/
              openFormat = :PowerPoint2007
              break
            else
              @files.push([entry.name,filecoding(zipfile.read(entry),entry.name)])
          end
        }
      }
      if openFormat.nil?
        :zip
      else
        @files = []
        openFormat
      end
      
    when /^(\x00{4}\x01)/ 
      # By AE6Y
      :CQPWIN
    when /^\x00{6} {10}/ && /^.{20}CQPIN/
      # this test is hacked ... if you add %% /^.{20}CQPIN to CQPWIN test then this test is never found
      :CQPDOS
    
    # Generic MS-Office file Multi-Stream Object Header   D0 CF 11 E0 A1 B1 1A E1
    when /^\xd0\xcf\x11\xe0\xA1\xB1\x1A\xE1\x00/
        # This is currently ugly and a little heavy handed...
      #     now just slam Excel into hash @data
      #     let the user decide what to do ...
      #
      book = Spreadsheet.open fn
      #book.worksheets.each do |s| puts "#{s.name}" end
      
      @data = {}
      book.worksheets.each do |x|
          tmp = []
              x.each do |row|
            line  = ''
            row.formatted.each do |cell|
                line << if (cell.to_s =~ /#<Spreadsheet/)
                cell.value.to_s.strip.ljust(10)
              else
                cell.to_s.strip.ljust(10) 
              end << ','
            end
            line.gsub!(/#<Spreadsheet::Formula[^>]+>/,'') # probably not needed now that we use value above
            line.gsub!(/(\d+)\.\d+/,'\1')
            tmp.push(line)
             end
           @data[x.name.to_sym] = tmp
       end
      :Excel
    #when /^\s*(#{@de}|#{@me}|#{@be}\s+){1,3}/
    # @ftype="ASCII log"
    when /^\x1B\x43\x00\f/
      #   ESC C NUL FF   <- EPSON printer code to set page length
      :PrinterCode
    when /^[A-Z0-9 .-:\/]+,[A-Z0-9 .-:\/]+,[A-Z0-9 .-:\/]+,[A-Z0-9 .-:\/]+/i
      :CSV
    when /^[ -~\n\t\r\f]+$/  #catchall test for ASCII file This must be last one checked
      :ASCII
    when /^\x52\x61\x72\x21\x1A/
      # Rar!      
      # RAR Archive
      :RAR
    when /^\x1F\x8B\x08/
      # GZIP file
      :GZIP
    when /^..\x00\x00\x47\x5A\x49\x50/
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
    if !file_name.nil?
      IO.foreach(file_name) {|line| @data.push(line) }
      @coding = filecoding(@data[0],file_name)
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
  def initialize(file_name=nil,mode=:r,type=:unknown)
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