#!/usr/bin/ruby

require 'ftools'

for fname in ARGV
  File.move( fname, "#{fname}.orig" )
  system( "cat ./header.java #{fname}.orig > #{fname}" )
  File.delete( "#{fname}.orig" )
end

