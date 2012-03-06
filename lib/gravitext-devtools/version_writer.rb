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

require 'gravitext-devtools'
require 'fileutils'
require 'rainbow'

module Gravitext
  module DevTools

    class VersionWriter
      include FileUtils

      attr_accessor :verbose

      def initialize
        @debug = false

        @git_lister = GitFileLister.new

        @version_patterns = {
          :history => [ /History\./, /^=== ([0-9a-z.]+) \((TBD|[0-9\-]+)\)/ ],
          :pom  => [ /pom\.xml$/,  /<version>([0-9a-z.]+)<\/version>/ ],
          :rb   => [ /(version|base)\.rb$/,
                     /VERSION\s*=\s*['"]([0-9a-z.]+)['"]/ ],
          :init => [ /init\//,  /^gem.+,\s*['"]=\s*([0-9a-z.]+)['"]/ ]
        }

        Hooker.apply( [ :gt, :version ], self )
      end

      def parse_options( args = ARGV )

        @git_lister.parse_options( args ) do |opts|
          opts.banner = "Usage: gt-version [options] dir|files ..."
          opts.on( "-d", "-debug", "Output full details" ) do
            @debug = true
          end
          opts.on( "-v", "--version V", "Specify new version", String ) do |v|
            @version = v
          end
        end
      end

      def run( args = ARGV )

        parse_options( args )

        # git_files = @git_lister.files

        args.each do |fname|
          process( fname )
        end

      end

      def process( fname )
        if fname =~ @version_patterns[ :history ][ 0 ]
          vline = @version_patterns[ :history ][ 1 ]
          lines = IO.readlines( fname )
          lines.each_index do |i|
            line = lines[i]
            if line =~ vline
              if $2 == 'TBD'
                lines[i] = "=== #{$1} (#{release_date})"
                rewrite_file( fname, lines )
                break
              else
                lines.insert( i, [ "=== #{@version} (TBD)",
                                   '' ] )
                rewrite_file( fname, lines )
                break
              end
            end
          end
        elsif fname =~ @version_patterns[ :pom ][ 0 ]
          vline = @version_patterns[ :pom ][ 1 ]
          lines = IO.readlines( fname )
          lines.each_index do |i|
            line = lines[i]
            if line =~ vline
              lines[i] =
                line.sub( /^(\s*<version>)([0-9a-z.]+)(<\/version>)/,
                          "\\1#{@version}\\3" )
              rewrite_file( fname, lines )
              break
            end
          end
        elsif fname =~ @version_patterns[ :rb ][ 0 ]
          vline = @version_patterns[ :rb ][ 1 ]
          lines = IO.readlines( fname )
          lines.each_index do |i|
            line = lines[i]
            if line =~ vline
              lines[i] =
                line.sub( /^(\s*VERSION\s*=\s*['"])([0-9a-z.]+)/,
                          "\\1#{@version}" )
              rewrite_file( fname, lines )
              break
            end
          end
        elsif fname =~ @version_patterns[ :init ][ 0 ]
          vline = @version_patterns[ :init ][ 1 ]
          lines = IO.readlines( fname )
          lines.each_index do |i|
            line = lines[i]
            if line =~ vline
              lines[i] =
                line.sub( /^(gem.+,\s*['"]=\s*)([0-9a-z.]+)/,
                          "\\1#{@version}" )
              rewrite_file( fname, lines )
              break
            end
          end
        end
      end

      def release_date
        Time.now.strftime( "%Y-%-m-%-d" )
      end

      def rewrite_file( file, lines )
        open( file, "w" ) { |fout| fout.puts( lines ) }
      end

    end

  end
end
