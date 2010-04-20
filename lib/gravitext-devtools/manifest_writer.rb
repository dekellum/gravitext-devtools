
require 'gravitext-devtools'
require 'fileutils'

module Gravitext
  module DevTools

    class ManifestWriter
      include FileUtils
      include Gravitext::DevTools

      # Set true if Manifest.txt should be written instead of Manifest.txt.
      # (Default: true if Manifest.static exists)
      # Boolean
      attr_accessor :static

      def initialize
        @verbose = false
        @static = File.exist?( 'Manifest.static' )

        @git_lister = GitFileLister.new

        @git_lister.exclusions = [ %r{(^|/).gitignore$},
                                   %r{(^|/).gt-config$},
                                   %r{(^|/)src(/|$)},
                                   'lib/**/*.jar',
                                   'Manifest.static' ]
      end

      def parse_options( args = ARGV )

        @git_lister.parse_options( args ) do |opts|
          opts.banner = "Usage:  gt-manifest [dir|file] ..."
          opts.on( "-v", "--verbose",
                   "Output full manifest details" ) do
            @verbose = true
          end
          opts.on( "-s", "--static",
                   "Write to Manifest.static instead of Manifest.txt" ) do
            @static = true
          end
        end
      end

      def run( args = ARGV )

        parse_options( args )

        @git_lister.extra_files << 'Manifest.txt' unless @static
        @git_lister.git_flags   << '-c' # Include cached by default

        files = @git_lister.files

        files.map! do |f|
          f = f.split( File::SEPARATOR )
          f.shift if f[0] == '.'
          f
        end
        files.uniq!
        files = sort( files )
        files.map! { |f| File.join( f ) }

        open( 'Manifest.' + ( @static ? 'static' : 'txt' ), 'w' ) do |out|
          files.each do |fname|
            puts fname if @verbose
            out.puts fname
          end
        end
      end

      def sort( files )

        files = files.sort do |a,b|
          i = 0
          o = 0
          while( o == 0 )
            o = -1 if ( a.length == i+1 ) && a.length < b.length
            o =  1 if ( b.length == i+1 ) && a.length > b.length
            o = a[i] <=> b[i] if o == 0
            i += 1
          end
          o
        end

        files = priority_to_base( files )

        files
      end

      # Move up any foo/base.rb or version.rb files. By convention
      # (originally based on rdoc issues) these come before a foo.rb, i.e:
      #
      #   lib/foo/base.rb
      #   lib/foo.rb
      #   lib/foo/other.rb
      #
      def priority_to_base( files )

        bases, nfiles = files.partition { |f| f.last =~ /^(base|version)\.rb$/ }

        bases.each do |base|
          key = base[0..-2]
          key[-1] += ".rb"
          nfiles.each_with_index do |file, i|
            if file == key
              nfiles.insert( i, base )
              base = nil
              break
            end
          end
          return files if base
        end

        nfiles
      end

    end


  end
end
