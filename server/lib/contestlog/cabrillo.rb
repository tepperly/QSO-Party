# Module for generating/reading Cabrillo log files
#
# Author:: N6RNO
# License::  &copy; 2014 Northern California Contest Club
#            2-Clause BSD License
#
# Version:: 3.0-0.1
#      Major/minor version number tied to Cabrillo specification
#
#
require 'contestlog/genericlog'

# for debugging convenience
require 'pp'

class Cabrillo < Genericlog
  
#OPTIMIZE: This class is rather heavy handed at the moment
#        The normal initialize, open calls will read the entire log file
#             and parse it into an internal structure when reading.
#         Writing is delayed until close. (Not actually implemented)
#         Appending is not currently supported.
#
#
# Design thoughts:
#
#    1 Read the entire file upon open, into an array of lines
#    2 Track header section separate from RAW QSO data.
#
#     1 Alternative approach (one currently implemented):
#     A Read header into header hash array  HASH is Cabrillo key-name
#     B Read QSO data into a 2d array
#        For supported contests (or ones where the user defines the format for us), the
#        QSO data be a hash array with the field names as the key. This is similar to how
#        ADIF data is stored in the ADIF QSO array.
#
# Cabrillo does not keep scoring information. Cabrillo does maintain a set of "judging" information
# that is in parallel to the QSO data array. Currently, this extension is captured as delimited data
# in the actual log file. The defined delimiters are {*GP ... GP*} . There is no provision to allow individual
# contests to define their own judging  extension (but there should be)
#
# Some specific noted extensions that have been implemented by some loggers:
# Note:: Technically all of these extensions make the Cabrillo file invalid and "strict" mode should flag them as such
#
#SD by EI5DI   adds the following "header" fields
#   X-VERSION, X-RADIOS, X-ANTENNAS, X-EMAIL, X-SUMMARY
#

#   Information from the specification for 3.0
#

#
# The specification requires that QSO data appear in chronological order. In actual usage, it should not be
#  needed. (Maybe we can force a sort on date/time to avoid the entire issue in the user's code, they can
#  treat the QSO data as if it was in date/time order and not worry about whether it was actually in date/time order.
#

# Official Contest Names
# Contest     Contest Symbol
# AP-SPRINT   AP-SPRINT
# ARRL-10     ARRL-10
# ARRL-160      ARRL-160
# ARRL-DX-CW    ARRL-DX-CW
# ARRL-DX-SSB   ARRL-DX-SSB
# ARRL-SS-CW    ARRL-SS-CW
# ARRL-SS-SSB   ARRL-SS-SSB
# ARRL-UHF-AUG  ARRL-UHF-AUG
# ARRL-VHF-JAN  ARRL-VHF-JAN
# ARRL-VHF-JUN  ARRL-VHF-JUN
# ARRL-VHF-SEP    ARRL-VHF-SEP
# ARRL-RTTY   ARRL-RTTY
# BARTG-RTTY    BARTG-RTTY
# CQ-160-CW   CQ-160-CW
# CQ-160-SSB    CQ-160-SSB
# CQ-WPX-CW   CQ-WPX-CW
# CQ-WPX-RTTY   CQ-WPX-RTTY
# CQ-WPX-SSB    CQ-WPX-SSB
# CQ-VHF      CQ-VHF
# CQ-WW-CW    CQ-WW-CW
# CQ-WW-RTTY    CQ-WW-RTTY
# CQ-WW-SSB   CQ-WW-SSB
# DARC-WAEDC-CW DARC-WAEDC-CW
# DARC-WAEDC-RTTY DARC-WAEDC-RTTY
# DARC-WAEDC-SSB    DARC-WAEDC-SSB
# FCG-FQP       FCG-FQP
# IARU-HF       IARU-HF
# JIDX-CW       JIDX-CW
# JIDX-SSB        JIDX-SSB
# NAQP-CW       NAQP-CW
# NAQP-RTTY     NAQP-RTTY
# NAQP-SSB      NAQP-SSB
# NA-SPRINT-CW    NA-SPRINT-CW
# NA-SPRINT-SSB   NA-SPRINT-SSB
# NCCC-CQP        NCCC-CQP
# NEQP          NEQP
# OCEANIA-DX-CW   OCEANIA-DX-CW
# OCEANIA-DX-SSB    OCEANIA-DX-SSB
# RDXC          RDXC
# RSGB-IOTA     RSGB-IOTA
# SAC-CW        SAC-CW
# SAC-SSB       SAC-SSB
# STEW-PERRY      STEW-PERRY
# TARA-RTTY     TARA-RTTY

# freq is frequency/band:
# 1800 or actual frequency in KHz
# 3500 or actual frequency in KHz
# 7000 or actual frequency in KHz
# 14000 or actual frequency in KHz
# 21000 or actual frequency in KHz
# 28000 or actual frequency in KHz
# 50
# 144
# 222
# 432
# 902
# 1.2G
# 2.3G
# 3.4G
# 5.7G
# 10G
# 24G
# 47G
# 75G
# 119G
# 142G
# 241G
# 300G

# mo is mode:
#   CW
# PH  Any phone mode SSB, USB, LSB, AM, FM unless FM is mode
#   FM
#   RY  RTTY

# Common powers
#
# Preferred   Alternatives
#   QRP     Q
#   LOW     L LO LP
#   HIGH    H HI HP

#
# We may want to introduce the concept of "strict" interpretation
#      The use must follow exactly the rules for Cabrillo. Any variation is flagged as an invalid Cabrillo log.
#

  class IllegalFormatError < TypeError
    # Actual log object (allows user a chance to recover from error)
    attr_accessor :log
    # Coded array of information about the specific failure. 1st element is the specific format error.
    # remaining elements are different for each of the types of errors.
    # Currently, we need to clean this up and provide a better recovery mechanism.
    attr_accessor :err
    def initialize(l=nil,e=nil)
      @log=l
      @err=e
    end
  end

  private

  # Possible legal values are:
  #    :loose   make best guess on intent
  #    :strict  must be completely legal per the identified log version on START-OF-LOG
  #    :3_0   strict 3.0 interpretation. (Maybe map strict 2.0 to 3.0 ???)
  #    :2_0  strict 2.0 interpretation. (Maybe map strict 3.0 to 2.0???)

  @@interpretation = :loose

  public

  # Cabrillo format specification. Defines which version of the log format specification to enforce.
  # Possible legal values are: 2.0, 3.0, :strict, :loose
  #   2.0/3.0 Forces strict interpretation of the stated format.
  #  :strict Means that the format version as specified by the log file will be strictly enforced.
  #  :loose (default). Best guess as to the intention is made.
  # Currently, only :loose is actually implemented.
  attr_accessor :spec

  #
  # Maybe not the best way.... not intuitive:
  #  pass a legal argument, spec is set and value returned
  #  pass an illegal argument, spec is not set and current value is returned
  #
  def spec=(s=:loose)
    case s
    when :loose , :strict
      @@spec = s
    when 'loose', 'strict', '3_0', '2_0'
      @@spec = s.to_sym
    when  3.0
      @@spec = '3_0'.to_sym
    when 2.0
      @@sepc = '2_0'.to_sym
    else
      @@interpretation
    end
  end

  private

  @@legal_keys = %w(
  START-OF-LOG
  ADDRESS ARRL-SECTION CALLSIGN CLAIMED-SCORE CLUB CONTEST
  CREATED-BY DEBUG-LEVEL IOTA-ISLAND-NAME LOCATION
  NAME OFFTIME  OPERATORS SOAPBOX
  CATEGORY CATEGORY-ASSISTED CATEGORY-BAND
  CATEGORY-DXPEDITION CATEGORY-MODE CATEGORY-OPERATOR
  CATEGORY-OVERLAY CATEGORY-POWER CATEGORY-STATION
  CATEGORY-TIME CATEGORY-TRANSMITTER
  CLUB-NAME QSO QTC
  END-OF-LOG
  )

  # Known contest formats
  #   The user can provide own format by calling define_contest
  #

  # Legal definition of contest QSO records (per contest)
  # Example template for ARRL SweepStakes:
  #   ARRL SweepStakes          --------info sent------- -------info rcvd--------
  #  QSO: freq  mo date              time            call       nr   p ck sec            call       nr   p ck sec
  #  QSO: ***** ** yyyy-mm-dd nnnn ********** nnnn a nn aaa ********** nnnn a nn aaa
  #  QSO: 21042 CW 1997-11-01 2102 N5KO          3 B 74 STX K9ZO          2 A 69 IL
  #     nnnn: serial number
  #     prec: precedence (A, B, M, Q, S or U)
  #     ck: two digit check
  #     sec: ARRL Section abbreviation
  #
  # id => [field count, f1,f2...]
  # just about every contest start out with FMDT fields ... maybe we should allow coding of this in a short form?
  # generally there is also special sent/recv data fields... we allow for this as a hierarchical setup ... see :cqp and :arrl_sweeps for examples
  #
  # Known coded fields are::  :freq,:mode:date,:time,:call,:nr,:qth,:prec,:ck,:sec,:zn,:name,:grid4,:grid6,:points
  # additional field codes are allowed but they are treated like strings
  #
  #---
  #   Note:   you may be tempted to code this like:
  #             fn = @@contest_fields.fetch(c,[-1]); fc = fn.shift
  #        This does not really work because fetch returns the actual object not a copy
  #         every time you fetch/shift you shorten the actual contents defined here
  #
  #         Instead use:
  #            fn=Array.new(@@contest_fields.fetch(c,[-1])); fc=fn.shift
  # ---
  @@contest_fields = {
    :cqp => [10,:freq,:mode,:date,:time, {:sent => [:call,:nr,:qth]},{:recv => [:call,:nr,:qth]}],
    :arrl_sweeps => [14,:freq,:mode,:date,:time,{:sent => [:call,:nr,:prec,:ck,:sec]},{:recv => [:call,:nr,:prec,:ck,:sec]}],
    :generic => [10,:freq,:mode,:date,:time, {:sent => [:call,:rst,:qth]},{:recv => [:call,:rst,:qth]}]
  }

  # Structural information about the _judged_data_ extension (per contest)
  # :re is the regular expression to find the actual data
  # :fields is the actual field definitions (needs a little work)
  # :jstart is the code to start the judged data in Cabrillo when written
  # :jend is the code to end the judged data in Cabrillo when written
  @@judged_data = {
    :cqp => {:re => Regexp.new("\\{GP[^}]+GP\\}"), :fields => [], :jstart => "{GP", :jend => "GP}"},
    :generic => {:re => Regexp.new("\\{JD[^}]+JD\\}"), :fields => [], :jstart => "{JD", :jend => "JD}"}
  }

  # Regular expression to check for legal QTH (per contest)
  @@legal_qth =  {
    :cqp => Regexp.new(
    "^(A[BKL]|AL(AM|PI)|AMAD|A[RZ]|BC|BUTT?|" <<
    "CALA?|CCOS?|C[OT]|COLU?|DE(LN)?|DX|" <<
    "ELDO?|FL|FRES?|[CGP]A|GLEN?|HI|HUMB|I[ADLN]|IMPE?|" <<
    "INYO?|KERN?|KING?|K[SY]|LA(KE|NG|SS)?|" <<
    "MA(DE|R[NP])?|M[BDE]|ME(ND|RC)|" <<
    "M[INORST]|MO(DO|NO|NT)|NAPA?|" <<
    "N[CDEHJMVY]|NEVA|O[HKNR]|" <<
    "ORAN|PLAC?|PLUM?|QC|RI|RIVE?|SACR?|" <<
    "SB(AR|E[NR])|SC(LA?|RU?)?|S[DK]|SDIE?|SFRA?|" <<
    "SHAS?|SIER?|SISK?|SJOA?|SLUI?|SMAT?|SOLA?|" <<
    "SONO?|STAN?|SUTT?|TEHA?|TN|TRIN|TULA?|TUOL|" <<
    "TX|UT|V[AT]|VENT?|W[AIVY]|XXXX|YOLO|YUBA|" <<
    "DL|VE[0-7]" <<
    ")$"),  # watch out for all the crazy dx guys, maybe a separate Regexp for DX ....
    :arrl_sweeps => Regexp.new(
    "^A[BKLRZ]|BC|C[OT]|DE|EB|[EW][MPW]A|" <<
    "GA|I[ADLN]|K[SY]|LAX?|M([BEINOST]|AR|DC)|" <<
    "N([CDEHLMTV]|LI)|[NS](FL|NJ)|[ENW]NY|[NSW]TX|" <<
    "O([HKNR]|RG)|PAC|PR|QC|RI|S([BCDFKV]|CV|DG|JV)|" <<
    "TN|UT|V[AIT]||W([IVY]|CF)" <<
    "$"), # out of date now 84 mults not the 80 encoded
    :generic => Regexp.new("^\S+$")
  }

  # Default values to jam into a field when the field is determined to be invalid (per contest)
  @@bad_fills = {
    :cqp => {:freq => 0000, :time =>2401,
    :date => "1970-01-01", :mode => "XX",
    :call => "XX0XX", :nr => 999_999, :qth => "XXXX",
    },
    :arrl_sweeps => {:freq => 0000, :time =>2401,
    :date => "1970-01-01", :mode => "XX",
    :call => "XX0XX", :nr => 999_999,
    :sec => "XXXX", :prec => "X", :ck=> -1
    },
    :generic => {:freq => 0000, :time =>2401,
    :date => "1970-01-01", :mode => "XX",
    :call => "XX0XX", :nr => 999_999, :qth => "XXXX",
    :sec => "XXXX", :prec => "U", :ck=> -1
    }
  }

  public

  # Returns true if field value is a default value. contest specifier is optional and defaults to :generic
  def default?(field_type,value,contest=:generic)
    value.eql?(@@bad_fills.fetch(contest,:generic).fetch(field_type,nil))
  end

  private

  # This function is the universal checker for a field,value set
  # It returns a properly formatted value, possibly doing data conversions
  # as supplied by the contest, for now it simply checks that the value is legal and returns
  # the value. If the value is not legal then the value is set to a value defined in @@bad_fills by field type.
  # There is a lot of conversion handling completely embedded within this code.
  # For now only CQP is actually properly handled but the arrl_sweeps  is also partially handled
  #
  # TDB:  error handling that gives our user a chance to recover from bad input
  #            we are really heavy handed here in that we often return _default_ value from @@bad_fills
  #            without actually telling the user.
  #
  def normalize_field(f,v,contest)

    if (! v.nil?)
      v.upcase!
    end

    v = case f
    when :freq
      # This can get tricky ... it might just be a full number in which case the value is
      # not divisible by 100 ... or it might be a band specifier ... see comments above
      # regarding legal values

      # lets try and get at known legal values
      #      need to possibly handle cm designators for 70cm (440) and the like....
      if (v =~ /[mg]/i)
        case v
        when '160M'
          1800
        when '80M'
          3500
        when '40M'
          7000
        when '20M'
          1400
        when '15M'
          2100
        when '10M'
          2800
        when '6M'
          50
        when '2M'
          144
        when '1.2G', '2.3G', '3.4G', '5.7G', '10G'
          # general VHF/UHF contest bands return values
          v
        when '24G', '47G', '75G', '119G', '142G', '241G','300G'
          v
        else
          @@bad_fills.fetch(contest,:generic).fetch(:freq,0)
        end
      else
        case v.to_i
        when 1800, 3500, 7000, 14000, 21000,  28000, 1800..29700
          # general HF contest bands   just return value
          v.to_i
        when 160
          1800
        when 80
          3500
        when 40
          7000
        when 20
          1400
        when 15
          2100
        when 10
          2800
        when 6
          50
        when 2
          144

        when 50, 144, 222, 432, 902,50..1300, 2300..3499, 5650..5925
          # general VHF/UHF contest bands return values
          v.to_i
        else
          @@bad_fills.fetch(contest,:generic).fetch(:freq,0)
        end # case
      end # if

    when :mode
      case v
      when 'CW'
        :CW
      when 'PH','SSB','USB','LSB','AM'
        :PH
      when 'FM'
        :FM
      when 'RTTY','RY','PSK','PSK31'
        :RY
      else
        @@bad_fills.fetch(contest,:generic).fetch(:mode,"XX")
      end

    when :date
      # built-in ruby date methods assume handling of date values that are consistent
      # with a setting, when dealing with logs we have to be more flexible in the
      # handling of the date, known legal examples include: (Using CQP 2008 as example date)
      # 10-5-08, 10-05-08, 10-5-2008, 10-05-2008, OCT-5-08, OCT-05-08, OCT-5-2008, OCT-05-2008
      # 2008-10-05,
      # Note: in the above you can change '-' to '/' or even '.' the other thing to deal with is non-USA
      # conventions : YDM YMD
      # Unfortunately, it is not actually possible to tell the difference between MDY and YDM or YMD
      # What rules to follow? When you only know the year (maybe).
      #
      #   Here are actual forms seen in the California QSO Party 2008 input stream
      #       (Excluding several cases where a time value was in the date field)
      #
      #    YYYY-MM-D?D   MM-D?D-YYYY    MM/D?D/YYYY  YYYY/MM/D?D YYYYMMDD
      v.gsub!(/\//,"-")
      v.sub!(/^(\d{4})(\d\d)(\d\d)$/,"\1-\2-\3")
      v.sub!(/^(\d\d)-(\d)-(.*)$/,"\1-0\2-\3")
      v.sub!(/^(\d)-(\d)-(.*)$/,"0\1-0\2-\3")
      v.sub!(/^(\d)-(\d\d)-(.*)$/,"0\1-\2-\3")

      #
      #   Nasty time, if all values are 2 digit we can not be really sure which is the year so...
      #            generally the number we are looking for is the first or last set
      #            In fact when a 2 digit year is present it is most often the last 2 digits
      #
      #   The only real way to fix this is to know that dates of the contest which
      #        currently is not available in the class.
      #
      #   so for now we simply will not properly handle this case.
      #    We will make a heavy handed slam by adding "20" to the front of the last
      #     date element.
      #
      # HACK HACK HACK
      v.sub!(/^(\d\d)-(\d\d)-(\d\d)$/,"\1-\2-20\3")

      # now final transform to move year to the front like it is supposed to be
      v.sub!(/^(\d\d-\d\d)-(\d{4})$/,"\2-\1")

      # still have the issue that we may not have a date field if actual supplied fields are out of order
      #      but by now we have abused what ever was actually sent and made it canonical
      #      if it is not YYYY-MM-DD by now, it is invalid and we should crib about it...
      #
      if (v.match(/^\d{4}-\d\d-\d\d$/) )
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:date,"1970-01-01")
      end

    when :time
      # ultimately time is a 24 hr UTC value in HHMM format
      if ( v =~ /^(2[0-3][0-5]\d|[0-1]\d[0-5]\d|\d[0-5]\d|[0-5]\d|\d)$/o )
        v.to_i
      else
        @@bad_fills.fetch(contest,:generic).fetch(:time,2401)

      end

    when :call
      # need a good regexp for valid looking calls
      if v =~ /\d/ && v=~ /[a-zA-Z]/
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:call,"XX0XX")
      end

    when :nr
      #
      # Some contests support a funny version of "number" where some send serial numbers and others
      #      send some sort of ID ..... Such as CIS-DX where CIS stations send CIS area code (RU11)
      #
      if ( v=~ /^\d+$/)
        v.to_i
      else
        @@bad_fills.fetch(contest,:generic).fetch(:nr,999_999)
      end

    when :qth
      # it would be nice to say QTH has to be only alpha
      #    but Canadian provinces are sometime like VE1 in some logs
      #    each contest needs to define a regexp that defines legal  set of QTH
      #    This code will allow the legal set through.
      #    It is up to the user code to fix-up "accepted" to full legal value.
      #       For example:   built-in :cqp allows TEH or TEHA for Tehama county.
      #                       Only TEHA is full legal value.
      #
      if (!v.nil?)
        if v.match(@@legal_qth.fetch(contest,"^\S+"))
          v
        else
          @@bad_fills.fetch(contest,:generic).fetch(:qth,"XXXX")
        end
      else
        @@bad_fills.fetch(contest,:generic).fetch(:qth,"XXXX")
      end

    when :prec
      #  untested ... not part of CQP
      if v.match(/^[ABMQSU]$/)
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:prec,'X')
      end

    when :ck
      #  untested ... not part of CQP 00-99
      if (0..99).member? v
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:ck,-1)
      end

    when :sec
      #  untested ... not part of CQP
      v

    when :rst
      #  untested ... not part of CQP
      #
      #   in contests RST is generally filler and is almost always 599 on cw  or  59 on phone
      #
      #     So for now we slam it to 599 if it is not 599/59
      #        the net effect of this "slam" is that RST field will pretty much match up except when 599 and 59
      #
      if v.eql?("599") || v.eql?("59")
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:rst,"599")
      end

    when :zn , :zone
      # CQ Zone 1-40
      if (1..40).member? v
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:zn,-1)
      end

    when :pts, :points
      # score value on qso ... just check it is a number
      if (v =~ /^\d+$/)
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:pts,0)
      end

    when :grid4, :grid
      # maidenhead 4 character grid
      if (v=~ /[A-R][A-R]\d\d/)
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:grid,"XX99")
      end

    when :grid6
      # maidenhead 6 character grid
      # traditionally the last two characters are lower case.
      # refer to http://en.wikipedia.org/wiki/Maidenhead_Locator_System
      #      Field         Square         Subsquare     ExtendedSubsquare (Not used in contests)
      #    Long, Lat
      if (v=~ /[A-R][A-R]\d\d/[A-X][A-X]/i)
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:grid6,"XX99ZZ")
      end

    when :name,:nm
      if (v =~ /^\S+$/)
        v
      else
        @@bad_fills.fetch(contest,:generic).fetch(:nm,"XX99ZZ")
      end

      #
      #  There are a whole bunch of contests that use all sorts of very special fields in Cabrillo
      #  Some have "member" number exchanges. Known (but not necessarily implemented) member number types are:
      #   10-10 <- 10-meter enthusiasts    http://www.ten-ten.org/
      #    070   <- May be defunct Pennsylvania Ohio DX  PSK CLUB hence 070 moniker 2005 date
      #   EPC <- European PSK Club
      #   FISTS
      #

    else
      v # unknown field type return value untouched
    end
    v
  end

  #
  # since mapping between formats is not uniformly bidirectional each class has to deal with getting from the other class
  #
  # Here is how we define the ADIF->CABRILLO mapping based upon the contest
  # This area needs a redesign to allow for a more generic mapper for each contest to handle
  # more than just ADIF files. We should allow a contest to handle any non-Cabrillo format log in a very
  # generic and simple way (Thought is needed to make this easy on the contest writer)
  # We need to create a mechanism that allows the most flexibility in converting arbitrary data.
  # Most flexible is we simply force the user to write their own code and we do nothing to help.
  # As of right now that is exactly what we do.
  #
  @@adif_map = {
    :cqp => nil,
    :arrl_sweeps => nil,
    :generic => nil
  }

  public

  # Simple extension mechanism to allow user to define their own contest. We encode all the contest logging information into
  # a set of internal data structures.
  def define_contest( id,fields,qth=@@legal_qth[:generic],fills=@@bad_fills[:generic])
    #
    #  id is a symbol that defines the name of the contest it should be uniq
    # fields is an array of symbols used to name QSO fields
    #
    @@contest_fields[id] = fields
    @@legal_qth[id] = qth
    @@bad_fills[id] = fills
  end

  private

  # Input:: Array of fields from log
  # Input:: Array of field numbers to delete. Order not important as we sort and delete right to left.
  # Output:: Array with fields removed
  def rm_fields_by_pos(line_data, *fl)
    # sort in reverse then delete
    #puts line_data.inspect
    fl.sort {|a,b| b <=> a}.each {|f|
      # puts "Delete field #{f}"
      line_data.delete_at(f)
    }
    #puts line_data.inspect
    line_data
  end

  # An attempt at getting valid data from QSO records. The challenge is that not all logs are legal.
  # Most common mistakes are missing/empty fields and adding extra fields like 599 when not part of contest definition.
  # Input:: qld -> QSO line data array one entry per field
  # Input:: contest -> contest type
  # Input:: field_count -> Expected number of fields in a QSO for this contest
  # Input:: log -> actual full log object (needed for error recovery)
  # Input:: fn -> Filename that holds actual log data (needed for error recovery)
  # Input:: line -> Line number in fn that is being processed (needed for error recovery)
  def format_qso_data(qld, contest, field_count,log,fn,line)
    #pp qld
    sz = qld.size
    qdata = Hash.new
    field_names = Array.new(@@contest_fields.fetch(contest))
    field_count = field_names.shift

    # A common mistake in some logs is to include RST when it is not part of the contest ... this happens
    #    mostly with the Europeans using SD by EI5DI version 14.09b

    #  So if there are too many fields, look for 599 fields to blast away (but check if RST in contest)
    #      Note: 3 assumptions:     1) sent/recv are symmetric     2) rst in sent/recv if present
    #                               3) It is highly improbable that sent :nr will be 599 on 1st Q ... we find this 599 to know which columns to purge
    #                                  we track this column in private vars:     @sent599_idx and @recv599_idx

    #puts "#{sz < field_count -1}"
    #puts "#{field_names.to_s !~ /rst/}"

    # the following code can not deal with a combination of added fields and missing fields that are balanced.
    #     if  fields_present - missing + added == expected  we have a problem
    #     if  fields_present -missing + added > expected we seem to be OK
    #     if fields_present -missing + added < expected results are not predictable and are probably wrong
    #               loose/strict compliance is not implemented yet and we have no clean error recovery scheme defined
    #               so we are likely to produce bad data when input is not stricly Cabrillo for the contest of interest.
    #
    #      The user's best course of action is to actually read the Cabrillo log twice:
    #              once with contest specified   (log.qsos returns a hash table of fields)
    #              once with no contest specified   (log.qsos returns an array of fields)
    #       User biz logic then can try and recover correctly but gets no real help from us until we
    #               implement error recovery/identification procedures.
    #

    if (sz > field_count)
      if (@sent599_idx > -1)
        rm_fields_by_pos(qld,@sent599,@recv599)
      elsif (field_names.to_s !~ /rst/)
        # HACK HACK HACK  above only searches for rst in sequence if a combination of field names could create this then this is broken
        #         for example if we ever had :r :s :t as separate fields then having having something like sent=>[ :r :s :t] breaks this
        #         also a more subtle break      sent=>[:callers :time] breaks the above DIRTY CHECK
        #    (Rhino)
        # search for those nasty 599 fields that we do not need nor want
        s599 = qld.index("599")
        r599 = qld.rindex("599")

        #puts "#{s599} #{r599}"
        #  now quickly check if we are good or there are other 599 like time or recv :nr that confuse the issue
        count599 = qld.inject(0) {|c,f|
          if f.eql?("599")
            c+1
          else
            c
          end
        }

        if count599 == 2
          # golden we can use this result
          @sent599 = s599
          @recv599 = r599
          rm_fields_by_pos(qld,@sent599,@recv599)
        else
          raise IllegalFormatError.new(log,[:too_many_fields,fn,line]),"Invalid Cabrillo format, too many fields.  Please provide a legal Cabrillo 3.0 format file"
        end
      end
    end

    field_names.each { |f|
      #    we need to be able to deal with missing/malformed data ...
      #    when we are expecting certain data we need to be able to
      #    recover when it is not present
      #
      #    missing data is one thing... data completely in the wrong column is another.
      #    hand created Cabrillo logs could have a lot of issues that we simply can not
      #    handle. The current design does not have logic to deal with really malformed
      #    Cabrillo logs.  In fact it will not even throw an exception.
      #
      if (f.to_s =~ /^(sent|recv)/)
        #pp "sent/recv #{f.inspect}"
        rsdata = Hash.new
        f.each { |k,v|
          v.each {|rsf|
            qf = qld.shift
            val = normalize_field(rsf,qf,contest)
            if (sz != field_count)
              # Potential need for fixup because of missing fields
              if (default?(rsf,val,contest))
                qld.unshift(qf)
              end
            end
            rsdata[rsf] = val
          }
          qdata[k] = rsdata
        }
      else
        #
        # Generally we expect these to be  :freq,:mode,:date, :time  as all contests define these fields and they are not
        #     actually part of the sent/recv sections of a QSO record
        #
        qf = qld.shift
        val = normalize_field(f,qf,contest)
        qdata[f] = val
      end
      #puts qdata.inspect
    }

    if (sz != field_count)
      # pp qdata.inspect
      # puts sz,field_count
    end

    @qsos.push qdata
    nil
  end

  public

  # Alter the contents of a header record.
  # This can be a challenge as a particular *key* may actually be an array.
  # Examples of arrayed keys are *SOAPBOX* and *ADDRESS*
  #
  # Direct access to QSO and QTC data is not permitted with this method
  def []=(key,*v)
    #  for now hack ... only alter only the first entry ... v seems to never be an array....
    k = key.upcase.gsub(/_/,'-')
    if k == 'QSO' || k == 'QTC'
      raise ArgumentError,"Key can not be QSO or QTC for []="
    else
      #puts "#{key} #{k} #{v} #{v.count} #{v[0]}  --  #{v[1]}"
      @headers.map! {|x|
        #puts "Does #{k} match #{x}"
        if x=~ /^#{k}:/
          #puts "matched #{k}"
          if v.count > 0
            "#{k}: #{v.pop}"
          else
            "#{k}: #{v}"
          end
        else
          x
        end
      }
    end
  end

  # Get the contents of a specific header field.
  # Returns an array if the *key* is present multiple times
  def [](key)
    k = key.upcase.gsub(/_/,'-')
    if k == 'QSO' || k == 'QTC'
      raise ArgumentError,"Key can not be QSO or QTC for []"
    else
      #puts "Find #{k}"
      retv = @headers.select{|x|
        #puts "Is it #{x}"
        x=~ /^#{k}:\s+/
      }
      retv.each { |x| x.sub(/^#{k}:\s+/,'')}
    end
  end

  #  actual real data in this class

  # Full header data
  # An array of all the header data, includes the field name (i.e.  "SOAPBOX: I really enjoyed this contest" )
  attr_accessor :headers
  # An array of the QTC data
  attr_accessor :qtcs
  # An array of all the QSO data
  # Each entry is a hash table. Key is the field name. :sent and :recv are composite fields in many contests.
  # formatting of each entry is controlled by the contest definition.
  attr_accessor :qsos
  # An array if all the "judging" data. Probably not created correctly when data is missing from some QSOs.
  attr_accessor :judge
  # Logger information - Not currently actually implemented
  attr_accessor :logger

  def initialize(log=nil, purpose=nil)
    #@data = File.readlines(fn)
    #
    @headers = Hash.new
    @sent599_idx = @recv599_idx = -1

    if log.style_is?(:zip)
      #
      # Make an attempt at recovery ... read a zipped Cabrillo file if we can find it.
      #    Also, need to make provisions for multiple Cabrillo files in one archive.
      #    This is not coded
      #
      # scan list of files previously read from log
      log.files.each { |file_info|
        if file_info[1].eql?(:Cabrillo)
          log.read_zip(fn,file_info[0])
          break
        end
      }

    end

    # either we found a Cabrillo log or converted to a Cabrillo log above or we opened one to start
    # Since all the above code flows to here and we check for Cabrillo log, the above code does not
    # have to do anything special when it can not create/convert/read a Cabrillo log
    #puts "#{log.coding}"
    if log.style_is?(:Cabrillo)
      @qsos = []
      @qtcs = []
      @judge = []
      # Clean up the generic read convert to internal Cabrillo form
      #   for now that means remove \r\n

      line = 0
      log.data.map { |x1|
        x = x1
        line +=1
        x.gsub!(/[\r\n]+/m,'')
        #puts "map(x)> #{x}"
        if x =~ /^QSO:/i
          x.sub!(/^QSO:\s+/i,'')

          # NCCC Green puts {GP ... GP} onto end of Cabrillo files
          #   making them only psuedo Cabrillo
          #
          judged = x.sub(/^.*(\{GP.*GP\}).*$/i,'\1')
          @judge.push(judged)
          x.sub!(/\{GP.*GP\}/i,'')

          #
          # Wait until after extension code to slam the input QSO record to uppercase
          #    This allows CQP judging data to have lower case comment data
          #
          x.upcase!

          # warning it is not clear that we can be this aggressive in the general case.... this is OK for CQP
          x.gsub!(/[,:'"`~!#$@%^&*()\{\}\[\];<>]/,'') # clear some odd things that happen in log
          #
          # There are some badly formed log files that merge fields together without spaces
          #      Early cabrillo logs had this behavior because the templates had no spaces and
          #      were not flexible. Modern Cabrillo files tend to have the spaces.
          #
          qso_line_data = x.scan(/\S+/)
          #puts qso_line_data.inspect
          if (qso_field_count > -1)
            format_qso_data(qso_line_data, purpose, qso_field_count, log,fn,line)
          else
            @qsos.push qso_line_data
          end

        elsif x =~ /^QTC:/i
          x.sub!(/^QTC:\s+/i,'')
          qtc_line_data = x.scan(/\S+/)

          if (defined? purpose)
            #
            # Specific known purpose usually contest... most contests do not handle QTC message traffic
            #
            puts "QTC Purpose is #{purpose}"
          end
          @qtcs.push(qtc_line_data)
          x = nil
        else
          key = x.sub(/^([^:]+).*$/,"\1")
          value = x.sub(/^[^:]+(.*)$/,"\1")
          @headers[key] = value;
          # save all the header data as provided
          #  header is anything that is not QSO: or QTC:
          #@headers.push x
        end
      }

      # only clear the old data if we are clean
      #puts @qsos.count
      #@qsos.each {|q| puts q.join(':')}

      log =nil
    else
      # can we provide programmer more information for recovery ?????
      raise IllegalFormatError.new(log,[:unsupported,log.style_is,fn,log.files]),"#{fn} is unsupported #{log.style_is} format.  Please provide a Cabrillo 3.0 format file"
    end
  end

  private

  #
  #   OK this is really really bad .... we really should refactor this entire file to use a log file type checker that can leverage known log file classes
  #      to extract log information.  More design needs to be done for this. The general idea is that a log file always contains header data and actual
  #      QSO data. In fact, based upon experience of the California QSO Party, users will upload almost anything. About 20% of the time there is not
  #      enough data to actually create a "generic log file" that can be judged in a contest. The worst cases simply do not have any valid QSO data at
  #      all. They are summary sheets.
  #
  # ADIF logs offer the 2nd most likely source of manageable contest data but without a lot of header data that is not standard
  #      and without interpolation of the existing data (such as sent #) you are not likely to be able to get all the information for
  #      contest judging.  For a contest that only uses RST, you might be able to convert to Cabrillo. Anything else is likely to not
  #      work. Therefore, ADIF->Cabrillo will not be written at this time as it is a waste of effort.
  #
  # In the case of CQP, the Excel format file that is provided might be able to get all the data for full QSO, but much like
  #      ADIF, some human intervention is needed as the date and band are often left blank part of the time forcing an
  #      interpolation scheme.... us the last valid value... simple enough but subject to error. It is also not immediately clear
  #      that we can properly read an Excel file in Ruby, therefore we will not write that reader either.
  #

  #
  #   Specialized routines to help give the user diagnostic information about the file
  #       by extracting identification information, we may be able to direct the user
  #       as to how to get us the log format that we want.
  #

end
