#!/usr/local/bin/ruby
require_relative 'cablog'

ARGV.shuffle.each { |arg|
  begin
    cab = Cabrillo.new(arg)
  rescue => e
    print "Filename: #{arg}\nException: #{e}\n"
  end
}
