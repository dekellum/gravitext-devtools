#--
# Copyright (c) 2008-2010 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You may
# obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

require 'gravitext-devtools'
require 'fileutils'
require 'erb'
require 'rubygems'
require 'rainbow'

module Gravitext
  module DevTools

    module Config
      def self.header
        hw = HeaderWriter.instance
        raise "HeaderWriter not initialized" unless hw
        yield hw
      end
    end

    class HeaderWriter
      include FileUtils

      attr_accessor :verbose
      attr_accessor :holder
      attr_accessor :inception
      attr_accessor :license
      attr_accessor :exclusions

      class << self
        attr_accessor :instance
      end

      def initialize
        @verbose = false
        @do_write = false
        @license = :apache
        @inception = Time.now.year

        @git_lister = GitFileLister.new

        @exclusions = [ %r{(^|/).gitignore$},
                        %r{(^|/).gt-config$},
                        'History.rdoc',
                        'Manifest.static',
                        'Manifest.txt',
                        'lib/**/*.jar',
                        'Rakefile' ]

        @cached_header = {}

        HeaderWriter.instance = self # The last created
      end

      def parse_options( args = ARGV )

        @git_lister.parse_options( args ) do |opts|
          opts.banner = "Usage:  gt-manifest [dir|file] ..."
          opts.on( "-v", "--verbose",
                   "Output full manifest details" ) do
            @verbose = true
          end
          opts.on( "-w", "--write",
                   "Write headers if needed" ) do
            @do_write = true
          end

        end
      end

      def run( args = ARGV )

        parse_options( args )

        Gravitext::DevTools.load_config_from_pwd

        @git_lister.exclusions = @exclusions
        # puts @exclusions.inspect

        files = @git_lister.files

        # puts cached_header( :rb )
        # exit

        files.each do |fname|
          HeaderProcessor.new( fname, @do_write ).process
        end
      end

      TDIR = File.expand_path( File.join( File.dirname( __FILE__ ),
                                          '..', '..', 'templates' ) )

      def cached_header( format )
        @cached_header[ format ] ||= gen_header( format )
      end

      def gen_header( format )
        efile = File.join( TDIR, 'format', "format.#{format}" )
        license = cached_license
        expand( IO.read( efile ), binding )
      end

      def cached_license
        @cached_license ||= gen_license
      end

      def gen_license
        template = if license.is_a?( Symbol )
                     IO.read( File.join( TDIR, 'license', license.to_s ) )
                   else
                     license.to_s
                   end
        expand( template, binding )
      end

      def expand( template, bnd )
        ERB.new( template, nil, '%' ).result( bnd ).map { |l| l.rstrip }
      end

      def years
        @years ||= [ inception, Time.now.year ].uniq.join( '-' )
      end
    end

    class HeaderProcessor

      CMAP = {}

      def self.mk_tag( name, color )
        tag = name.foreground( color )
        CMAP[ tag ] = color
        tag
      end

      GOOD  = mk_tag( "GOOD ",  :green )
      NONE  = mk_tag( "NONE ",  :red )
      DATE  = mk_tag( "DATE ",  :cyan )
      EMPTY = mk_tag( "EMPTY", :yellow )
      WROTE = mk_tag( "WROTE", :yellow )

      def initialize( fname, do_write = false )
        @cpos = 0
        @do_write = do_write
        @fname = fname
        @format = case fname
                  when /\.java$/
                    :java
                  when /\.xml$/
                    :xml
                  when /\.rb$/
                    :rb
                  else
                    :txt
                  end
        @state = :first
        @writer = HeaderWriter.instance
      end

      def process
        state = GOOD
        @lines = IO.readlines( @fname )
        if @lines.empty?
          state = EMPTY
        else
          scan_prolog
          if find_copyright
            if !check_copyright
              if @do_write
                rewrite_file
                state = WROTE
              else
                state = DATE
              end
            end
          else
            if @do_write
              insert_header
              rewrite_file
              state = WROTE
            else
              state = NONE
            end
          end
        end
        puts( "%s %s" %
              [ state, @fname.dup.foreground( CMAP[ state ] ) ] )
      end

      def rewrite_file
        open( @fname, "w" ) { |fout| fout.puts( @lines ) }
      end

      def scan_prolog

        if @lines[0] =~ /^#\!([^\s]+)/
          @format = :rb if $1 =~ /ruby$/
          @cpos = 1
        end

        if @lines[0] =~ /^<?xml/
          @format = :xml
          @cpos = 1
        end

        @lines.each_index do |i|
          line = @lines[i]
          if line =~ /^#.*-\*-\s*ruby\s*-\*-/
            @format = :rb
            @cpos = i+1
            break
          else
            break if line !~ /^\s*#/
          end
        end

      end

      def find_copyright
        @cline = nil
        @lines.each_index do |i|
          line = @lines[i]
          case @format
          when :rb
            case line
            when /^#\s+Copyright/
              @cline = i
              break
            when /^\s*$/
            when /^\s*[^#]/
              break
            end
          when :java
            case line
            when /^\s*\*\s+Copyright/
              @cline = i
              break
            when /^\s*$/
            when /^\s*[^\/\*]/
              break
            end
          else
            if line =~ /Copyright \([cC]\)/
              @cline = i
              break
            end
          end
        end
        @cline
      end

      def check_copyright
        passes =
          if @lines[@cline] =~ /Copyright \(c\) (\d{4})(-(\d{4}))? (\S.*)\s*$/
            ldate = $3 || $1 #last date
            ldate && ( ldate == Time.now.year.to_s ) && ( $4 == @writer.holder )
          else
            false
          end

        unless passes
          start = @lines[@cline].match( /^.*Copyright/ )
          @lines[@cline] = [ start, "(c)",
                             @writer.years, @writer.holder ].join( ' ' )
        end

        passes
      end

      def insert_header
        header = @writer.cached_header( @format )
        @lines.insert( @cpos, *header )
        @cpos += header.length
        # Insert an extra line break if needed.
        @lines.insert( @cpos, "" ) unless @lines[ @cpos ] =~ /^\s*$/
      end

    end

  end
end
