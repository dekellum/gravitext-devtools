require 'gravitext-devtools/base.rb'
require 'optparse'

module Gravitext
  module DevTools

    class GitFileLister

      # Exclusions to the list expressed in various ways
      # Array<Regexp|Proc|String>
      attr_accessor :exclusions

      # Flags for use in call to git ls-files
      # Array<~to_s>
      attr_accessor :git_flags

      # Additional files to add to files list
      # Array<~to_s>
      attr_accessor :extra_files

      def initialize
        @args = []
        @files = nil
        @exclusions = [ %r{(^|/).gitignore$},  # gt-manifest, gt-header
                        %r{(^|/).gt-config$},  # gt-manifest, (gt-header)
                        %r{(^|/)src(/|$)},     # gt-manifest
                        'lib/**/*.jar',        # all
                        'Manifest.static' ]    # gt-manifest, gt-header
        @git_flags = []
        @extra_files = []
      end

      def parse_options( args = ARGV, &block )
        opts = OptionParser.new do |opts|
          opts.on( "-g", "--git-updates",
                   "Include files from modified/untracked git working tree" ) do
            @git_flags += %w[ -m -o --exclude-standard ]
          end
          block.call( opts ) if block
        end
        @args = opts.parse( args )
      end

      def files
        @files ||= generate_list
      end

      def generate_list( args = @args )

        files, dirs = args.partition { |a| File.file?( a ) }

        if files.empty? || ! dirs.empty?
          gcmd = [ 'git', 'ls-files', @git_flags, dirs ].flatten.compact.join( ' ' )
          files += IO.popen( gcmd ) { |inp| inp.readlines }
        end

        files += extra_files

        files.map! { |f| f.strip }
        files.uniq!
        files.reject { |f| exclude?( f ) }
      end

      def exclude?( fname )
        @exclusions.any? do |ex|
          case ex
          when Proc
            ex.call( fname )
          when Regexp
            fname =~ ex
          when /[*?]/
            File.fnmatch?( ex, fname, File::FNM_PATHNAME )
          else
            fname == ex
          end
        end
      end

    end

  end
end
