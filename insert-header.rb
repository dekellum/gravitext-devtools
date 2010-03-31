#!/usr/bin/ruby

require 'fileutils'
include FileUtils

HDIR = File.dirname( __FILE__ )

for fname in ARGV
  if system( %q{egrep -q '^[ \*#]+Copyright ' } + fname  )
    puts "#{fname} already has Copyright header."
  else
    hfile = HDIR + '/' +
      if fname =~ /\.java$/
        'header.java'
      elsif fname =~ /\.xml$/
        'header.xml'
      else
        'header.rb'
      end
    mv( fname, "#{fname}.orig" )
    system( "cat #{hfile} #{fname}.orig > #{fname}" )
    rm( "#{fname}.orig" )
    puts "#{fname} : header applied."
  end
end
