
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

      class << self
        attr_accessor :instance
      end

      def initialize
        @verbose = false
        @license = :apache
        @inception = Time.now.year

        @git_lister = GitFileLister.new

        @git_lister.exclusions = [ %r{(^|/).gitignore$},
                                   %r{(^|/).gt-config$},
                                   'lib/**/*.jar',
                                   'Manifest.static' ]

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

        files = @git_lister.files

        puts cached_header( :rb )
        exit
        files.each do |fname|
          process( fname )
        end

        # for fname in files
        #   if system( %q{egrep -q '^[ \*#]+Copyright ' } + fname  )
        #     puts "#{fname} already has Copyright header."
        #   else
        #     hfile = HDIR + '/' +
        #       if fname =~ /\.java$/
        #         'header.java'
        #       elsif fname =~ /\.xml$/
        #         'header.xml'
        #       else
        #         'header.rb'
        #       end
        #     #mv( fname, "#{fname}.orig" )
        #     #system( "cat #{hfile} #{fname}.orig > #{fname}" )
        #     #rm( "#{fname}.orig" )
        #     puts "#{fname} : header applied."
        #   end
        # end

      end

      def process( fname )
        flines = IO.readlines( fname )
        
      end

      TDIR = File.expand_path( File.join( File.dirname( __FILE__ ),
                                          '..', '..', 'templates' ) )

      def cached_header( format )
        @cached_header[ format ] ||= gen_header( format )
      end

      def gen_header( format )
        efile = File.join( TDIR, 'format', "format.#{format}" )
        license = cached_license
        ERB.new( IO.read( efile ), nil, '%>' ).result( binding )
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
        ERB.new( template, nil, '%>' ).result( binding )
      end

      def years
        @years ||= [ inception, Time.now.year ].uniq.join( '-' )
      end
    end
  end
end
