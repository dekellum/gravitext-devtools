#--
# Copyright (c) 2008-2012 David Kellum
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

require 'gravitext-devtools/base.rb'
require 'optparse'

require 'rubygems'
require 'hooker'

module Hooker
  class << self
    # Deprecated, use setup_header instead.
    def header( &block )
      add( [ :gt, :header ], caller.first, &block )
    end
  end

  log_with { |m| puts m }
end

module Gravitext
  module DevTools

    def self.configure( &block )
      Hooker.with( :gt, &block )
    end

    def self.load_config_from_pwd
      count = 0
      pwd = File.expand_path( Dir.pwd )
      while( File.directory?( pwd ) )
        cfile = File.join( pwd, '.gt-config' )
        if File.exist?( cfile )
          Hooker.load_file( cfile )
          break
        end
        break if File.exist?( File.join( pwd, '.git' ) )
        pwd = File.dirname( pwd )
        break if ( count += 1 ) > 4
        break if pwd == '/'
      end
    end

    class GitFileLister

      # Inclusions to the list expressed in various ways
      # Array<Regexp|Proc|String>
      attr_accessor :inclusions

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
        @inclusions = []
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
        unless @inclusions.empty?
          files = files.select { |f| match?( @inclusions, f ) }
        end
        files.reject { |f| match?( @exclusions, f ) }
      end

      def match?( list, fname )
        list.any? do |ex|
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
