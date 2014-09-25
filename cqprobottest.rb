#/usr/bin/env ruby
# 
# Requires the following gems:
#    multipart-post    https://gethub.com/nickseiger/multipart-post
#    
# Developed and testing with Ruby 2.1.x

require 'net/http'
require 'uri'
require 'net/http/post/multipart'
require 'json'
require 'getoptlong'

$email = "cqp.test2014@gmail.com"
$phone = "925-961-0777"


def guessEncoding(str)
  if str.encoding == Encoding::ASCII_8BIT
    isASCII = true
    utfCount = 0
    str.each_byte { |c|
      if (c & 0x80) == 0
        if utfCount > 0
          return Encoding::Windows_1252
        end
      else
        isASCII = false
        if utfCount > 0
          if (c & 0xc0) == 0x80
            utfCount = utfCount - 1
          else
            return Encoding::Windows_1252
          end
        else
          if (c & 0xe0) == 0xc0
            utfCount = 1        # expect byte 2
          elsif (c & 0xf0) == 0xe0
            utfCount = 2        # expect bytes 2 & 3
          elsif (c & 0xf8) == 0xf0
            utfCount = 3        # expect bytes 2, 3, & 4
          else
            return Encoding::Windows_1252
          end 
        end
      end
    }
    if utfCount > 0
      return Encoding::Windows_1252
    else
      if isASCII
        return Encoding::US_ASCII
      else
        return Encoding::UTF_8
      end
    end
  else
    str.encoding
  end
end

def toUTFCompat(content)
  encoding = guessEncoding(content)
  if not [Encoding::US_ASCII, Encoding::UTF_8].include?(encoding)
    begin
      content = content.force_encoding(encoding)
      content = content.encode(Encoding::UTF_8)
    rescue => e
      $stderr.puts("Encoding fail\n")
    end
  end
  content
end
  

class MultiGet
  def initialize(host, port=nil)
    @host = host
    @port = port
    @lastResult = nil
    @bytes_uploaded = 0
    @seconds_uploading = 0
    @bytes_downloaded = 0
    @seconds_downloading = 0
    @files_downloaded = 0
    @files_failed = 0
    @uri_for_failed = [ ]
  end

  def openConn
    return Net::HTTP.new(@host, @port)
  end

  def getFiles(files, filename="")
    @lastResult = nil
    success = 0
    conn = openConn
    start = Time.now
    files.each { |file|
      begin
        resp = conn.get(file)
        @lastResult = (resp.code == "200")
        if @lastResult
          success = success + 1
          @files_downloaded = @files_downloaded + 1
        else
          @files_failed = @files_failed + 1
          @uri_for_failed.push(file + " get (" + filename + ") " + resp.code)
        end
        body = resp.body
      rescue => e
        @files_failed = @files_failed + 1
        @uri_for_failed.push(file + " get (" + filename + ") " + e.class.to_s + " '" + e.message + "'")
        body = nil
      end
      if body
        @bytes_downloaded = @bytes_downloaded + body.length
      end
    }
    finish = Time.now
    @seconds_downloading = (finish - start)
    success
  end

  def to8bit(str)
    if not str.instance_of?(String)
      str = str.to_s
    end
    if str.encoding != Encoding::ASCII_8BIT
      str.dup.force_encoding(Encoding::ASCII_8BIT)
    else
      str
    end
  end

  def convertEncoding(data)
    result = Hash.new
    data.each { |k,v|
      result[to8bit(k)] = to8bit(v)
    }
    result
  end

  def post(path, data, filename="")
    verbose=nil
    @lastResult = nil
    encodedData = URI.encode_www_form(convertEncoding(data))
    conn = openConn
    start = Time.now
    if verbose
      print encodedData + "\n"
    end
    begin
      resp = conn.post(path, encodedData, 
                        {'Content-Type' => 
                          'application/x-www-form-urlencoded'})
      finish = Time.now
      @bytes_uploaded = @bytes_uploaded + encodedData.length
      @bytes_downloaded = @bytes_downloaded + resp.body.length
      if (@bytes_uploaded > 0 or @bytes_downloaded > 0)
        @seconds_uploading = (@bytes_uploaded.to_f/(@bytes_uploaded+@bytes_downloaded))*(finish - start)
        @seconds_downloading = (@bytes_downloaded.to_f/(@bytes_uploaded+@bytes_downloaded))*(finish - start)
      end
      @lastResult = (resp.code == "200")
      if @lastResult
        @files_downloaded = @files_downloaded + 1
      else
        @files_failed = @files_failed + 1
        @uri_for_failed.push(path + " post (" + filename + ") " + resp.code)
      end
      resp.body
    rescue => e
      @files_failed = @files_failed + 1
      @uri_for_failed.push(path + " post (" + filename + ") "  + e.class.to_s + " '" + e.message + "'")
      ""
    end
  end

  def uploadFile(path, fileio, callsign, filename="")
    @lastResult = nil
    conn = openConn
    request = Net::HTTP::Post::Multipart.new(path, "cabrillofile" => 
                                             UploadIO.new(fileio, "text/plain", callsign + ".log"))
    begin
      response = conn.request(request)
      @lastResult = (response.code == "200")
      if @lastResult
        @files_downloaded = @files_downloaded + 1
      else
        @files_failed = @files_failed + 1
        @uri_for_failed.push(path + " upload (" + filename + ") " + response.code)
      end
      response.body
    rescue => e
      @files_failed = @files_failed + 1
      @uri_for_failed.push(path + " upload(" + filename + ") "  + e.class.to_s  + " '" + e.message + "'")
      ""
    end
  end

  def lastSuccess?
    @lastResult
  end

  attr_reader :seconds_downloading, :bytes_downloaded, :files_downloaded, 
     :files_failed, :bytes_uploaded, :seconds_uploading, :uri_for_failed

  def sendRate
    if @seconds_uploading > 0
      @bytes_uploaded/@seconds_uploading.to_f
    else
      0
    end
  end

  def readRate
    if @seconds_downloading > 0
      @bytes_downloaded/@seconds_downloading.to_f
    else
      0
    end
  end
end


def getID(json)
  begin
    obj = JSON.parse(json)
    obj["files"][0]["id"].to_i
  rescue JSON::ParserError
    nil
  end
end

OPCLASSES = [ "single", "multi-single", "multi-multi", "checklog" ]

POWER = %w( Low High QRP )

SENTQTH = %w( ALAM ALPI AMAD BUTT CALA CCOS COLU DELN ELDO FRES GLEN
HUMB IMPE INYO KERN KING LAKE LANG LASS MADE MARN MARP MEND MERC MODO
MONO MONT NAPA NEVA ORAN PLAC PLUM RIVE SACR SBAR SBEN SBER SCLA SCRU
SDIE SFRA SHAS SIER SISK SJOA SLUI SMAT SOLA SONO STAN SUTT TEHA TRIN
TULA TUOL VENT YOLO YUBA AL MI TX AK MN UT UT AZ MS VT AR MO VA MT WA
CO NE WV CT NV WI DE NH WY FL NJ GA NM MR HI NY ID NC IL ND IN OH QC
IA OK ON KS OR MB KY PA SK LA RI AB ME SC BC MD SD NT MA TN DX )

def randomHdr(id, callsign)
  hdr = { }
  hdr["logID"] = id
  hdr["callsign"] = callsign.to_s
  hdr["email"] = $email
  hdr["confirm"] = $email
  hdr["phone"] = $phone
  hdr["sentQTH"] = SENTQTH[rand(SENTQTH.length)]
  hdr["opclass"] = OPCLASSES[rand(OPCLASSES.length)]
  hdr["power"] = POWER[rand(POWER.length)]
  [ "expedition", "youth", "mobile", "female", "school", "new" ].each { |label|
    if rand(2) == 1
      hdr[label] = ""
    end
  }
  hdr["comments"] = "Lorem ipsum dolar"
  return hdr
end

def filenameToCall(filename)
  base = File.basename(filename)
  if (base =~ /^([^-]+)-([0-9M]-)?/i)
    if $2
      return $1 + "/" + $2[0]
    else
      return $1
    end
  else
    return "UNKNOWN"
  end
end


class FormOne
  FORM_ONE_OR_TWO = [
                    '/cqp/logsubmit-form.html',
                    '/cqp/css/jquery.fileupload.css',
                    '/cqp/css/cqp_style.css',
                    '/cqp/js/jquery.iframe-transport.js',
                    '/cqp/js/vendor/jquery.ui.widget.js',
                    '/cqp/favicon.ico',
                    '/cqp/js/jquery.fileupload.js',
                    '/cqp/images/cqplogo80075.jpg'
                   ]
  def initialize(multiget, filename)
    @success = nil
    @filename = filename
    @mg = multiget
    @callsign = filenameToCall(filename)
  end

  def upload(io)
     @mg.uploadFile("/cqp/server/upload.fcgi", io, @callsign)
  end

  def runForm
    @mg.getFiles(FORM_ONE_OR_TWO, @filename)
    open(@filename, "rb") { |io|
      json = upload(io)
      if json and (id = getID(json))
        stepTwo(id)
        @success = true
      else
        @success = false
      end
      @mg.getFiles(["/cqp/server/received.fcgi",], @filename)
      @success = @mg.lastSuccess? and @success
    }
  end

  def stepTwo(id)
    hdr = randomHdr(id, @callsign)
    hdr["source"] = "form1"
    @mg.post("/cqp/server/upload.fcgi", hdr, @filename)
  end

  def success?
    @success
  end

end

class FormTwo < FormOne
  
  def stepTwo(id)
    hdr = randomHdr(id, @callsign)
    hdr["source"] = "form2"
    @mg.post("/cqp/server/upload.fcgi", hdr, @filename)
  end

  def upload(io)
    content = toUTFCompat(io.read())
    src = @mg.post("/cqp/server/upload.fcgi", { "cabcontent" => content }, @filename)
    content = nil
    src
  end

end

class FormThree
  FORM_THREE = [
                '/cqp/logsubmit-form.html',
                '/cqp/css/jquery.fileupload.css',
                '/cqp/css/cqp_style.css',
                '/cqp/favicon.ico',
                '/cqp/images/cqplogo80075.jpg'
               ]

  def initialize(multiget, filename)
    @success = nil
    @mg = multiget
    @filename = filename
    @callsign = filenameToCall(filename)
  end

  def runForm
    @mg.getFiles(FORM_THREE)
    open(@filename, "rb") { |io|
      hdr = randomHdr(-1, @callsign)
      hdr["source"] = "form3"
      content = toUTFCompat(io.read())
      hdr["cabcontent"] = content
      @mg.post("/cqp/server/upload.fcgi", hdr, @filename)
      @success = @mg.lastSuccess?
      @mg.getFiles(["/cqp/server/received.fcgi",], @filename)
      @success = @mg.lastSuccess? and @success
    }
  end

  def success?
    @success
  end
end


class MyRunner
  def initialize(queue, forms)
    @m = MultiGet.new("robot.cqp.org")
    @queue = queue
    @forms = forms
    @success = 0
    @failure = 0
    @failed = [ ]
  end
  
  def run
    while filename = @queue.pop
      ft = @forms[rand(@forms.length)]
      case ft
      when "form1"
        f = FormOne.new(@m, filename)
      when "form2"
        f = FormTwo.new(@m, filename)
      when "form3"
        f = FormThree.new(@m, filename)
      end
      f.runForm
      if f.success?
        @success = @success + 1
      else
        @failure = @failure + 1
        @failed << filename
      end
    end
  end
  
  def filesDownloaded
    @m.files_downloaded
  end

  def filesFailed
    @m.files_failed
  end

  def uriFailed
    @m.uri_for_failed
  end

  def readRate
    @m.readRate
  end
  
  def sendRate
    @m.sendRate
  end

  attr_reader :success, :failure, :failed
end





uploadSuccess = 0
uploadFailed = 0

opts = GetoptLong.new(['--shuffle', GetoptLong::NO_ARGUMENT ],
                      ['--email', GetoptLong::REQUIRED_ARGUMENT],
                      ['--phone', GetoptLong::REQUIRED_ARGUMENT],
                      ['--form', GetoptLong::REQUIRED_ARGUMENT],
                      ['--threads', GetoptLong::REQUIRED_ARGUMENT])

shuffle = nil
forms = ["form1", "form2", "form3"]
numthreads = 1

opts.each { |opt,arg|
  case opt
    when '--shuffle'
      shuffle = true
    when '--email'
      $email = arg
    when '--phone'
      $phone = arg
    when '--form'
      forms = arg.split(",")
    when '--threads'
      numthreads = arg.to_i
      if numthreads > 32
        numthreads = 32
      end
  end
}
                      
files = ARGV.dup
if shuffle
  files.shuffle!
end

runners = [ ]
threads = [ ]
numthreads.times { 
  r = MyRunner.new(files, forms)
  runners.push(r)
  threads.push(Thread.new { r.run })
}

threads.each { |thr|
  thr.join()
}
  
uploadSuccess = runners.inject(0) { |sum, n| sum + n.success }
uploadFailed = runners.inject(0) { |sum, n| sum + n.failure }
filesDownloaded = runners.inject(0) { |sum, n| sum + n.filesDownloaded}
failedUploads = runners.inject([]) { |sum, n| sum + n.failed}
failedFiles = runners.inject([]) { |sum, n| sum + n.uriFailed}
filesFailed = runners.inject(0) { |sum, n| sum + n.filesFailed}
readRate = (runners.inject(0.0) { |sum, n| sum + n.readRate})/runners.length.to_f
sendRate = (runners.inject(0.0) { |sum, n| sum + n.sendRate})/runners.length.to_f



print uploadSuccess.to_s + " successful uploads.\n"
print uploadFailed.to_s + " failed uploads.\n"
print filesDownloaded.to_s + " files fetched.\n"
print filesFailed.to_s + " files failed.\n"
print readRate.to_s + " bytes/second read.\n"
print sendRate.to_s + " bytes/second sent.\n"

print "Uploads that failed\n===================\n"
failedUploads.each { |filename| 
  print filename + " failed\n"
}
print "Files that failed\n=================\n"
failedFiles.each { |filename| 
  print filename + " failed\n"
}
