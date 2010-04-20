
require 'gravitext-devtools'
require 'fileutils'
require 'erb'

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
        @license = :apache
        @inception = Time.now.year

        @git_lister = GitFileLister.new

        @exclusions = [ %r{(^|/).gitignore$},
                        %r{(^|/).gt-config$},
                        'History.rdoc',
                        'Manifest.static',
                        'Manifest.txt',
                        'README.rdoc',
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
          HeaderProcessor.new( fname ).process
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
      def initialize( fname )
        @cpos = 0
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
      end

      def process
        puts @fname #FIXME
        @lines = IO.readlines( @fname )
        unless @lines.empty?
          scan_prolog
          if find_copyright
          else
            insert_header
            #FIXME puts "write!"
            rewrite_file
          end
        end
      end

      def rewrite_file
        open( @fname, "w" ) { |fout| fout.puts( @lines ) }
      end

      def scan_prolog
        if @lines[0] =~ /^#\!([^\s]+)/

          @format = :rb if $1 =~ /ruby$/
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
            when /^\s*[^#]/
              break
            end
          when :java
            case line
            when /^\*\s+Copyright/
              @cline = i
              break
            when /^\s*[^\*]/
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

      def insert_header
        header = HeaderWriter.instance.cached_header( @format )
        @lines.insert( @cpos, *header )
        @cpos += header.length
        # Insert an extra line break if needed.
        @lines.insert( @cpos, "" ) unless @lines[ @cpos ] =~ /^\s*$/
      end

    end

  end
end
