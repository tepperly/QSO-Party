#!/usr/bin/env ruby
#

require 'net/http'
require 'json'
require 'open-uri'
require 'time'

RESTTIME = 60 * 15              # check every 15 minutes
JITTER = 60
MAX_TIME_BETWEEN = 24 * 60 * 60 # 24 hours in seconds
MAX_LOGS = 25

begin
  timestr = File.read("last_backup.txt")
  $lastBackup = Time.at(timestr.to_i)
rescue => e
  $lastBackup = Time.at(0)      # beginning of Epoch
end
$lastCount = 0

def makeBackup
  $lastBackup = Time.now
  print "Make backup: " + $lastBackup.to_s + "\n"
  system("./cqp_backup")
  File.write("last_backup.txt", $lastBackup.to_i.to_s)
end

def readStats
  begin
    open("http://robot.cqp.org/cqp/server/stats.fcgi") { |f|
      hash = JSON.parse(f.read)
      if hash["date"].nil?
        return hash["count"].to_i, nil
      else
        return hash["count"], Time.parse(hash["date"])
      end
    }
  rescue => e
  end
  return nil, nil
end

while true
  count, date = readStats
  if (not date) or ($lastBackup < date) # new logs are on the server
    if ((not count) or (count >= $lastCount + MAX_LOGS)) or
        (Time.now - $lastBackup) >= MAX_TIME_BETWEEN
      makeBackup
      if count
        $lastCount = count
      end
    end
  end
  sleep(RESTTIME + (0.5 - rand)*JITTER)
end
