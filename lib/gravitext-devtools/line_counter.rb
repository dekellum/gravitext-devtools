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

module Gravitext
  module DevTools

    class LineCounter
      include FileUtils
      include Gravitext::DevTools

      def initialize
        @verbose = false
        @git_lister = GitFileLister.new
      end

      def parse_options( args = ARGV )

        @git_lister.parse_options( args ) do |opts|
          opts.banner = "Usage:  gt-count [dir|file] ..."
          opts.on( "-v", "--verbose",
                   "Output per file counts" ) do
            @verbose = true
          end
        end
      end

      def run( args = ARGV )

        parse_options( args )

        @git_lister.exclusions = []
        git_files = @git_lister.files

        show_count_line( "LANG/FILE", "LINES", "CODE" )
        total_lines = total_code = 0

        map = [ [ 'JAVA', [ '**/*.java' ] ],
                [ 'RUBY', [ '**/*.rb', '**/bin/*', '**/init/*',
                            '**/Rakefile', '**/Gemfile', '**.gemspec' ] ] ]

        map.each do | lang, fpats |
          files = git_files.select { |f| @git_lister.match?( fpats, f ) }
          lines, codelines = count_files( files )
          show_count_line( lang, lines, codelines )
          total_lines += lines
          total_code  += codelines
        end
        show_count_line( "TOTAL", total_lines, total_code)

      end

      def count_lines( filename )
        lines = codelines = 0
        is_java = ( filename =~ /\.java$/ )

        open( filename, 'rb' ) { |f|
          f.each do |line|
            lines += 1
            next if line =~ /^\s*$/
            next if line =~ ( is_java ? %r{\s*[/*]} : /^\s*#/ )
            codelines += 1
          end
        }
        [ lines, codelines ]
      end

      def show_count_line(msg, lines, code)
        printf( "%6s %6s %s\n", lines.to_s, code.to_s, msg )
      end

      def count_files( files )
        total_lines = total_code = 0
        files.each do |fn|
          lines, codelines = count_lines( fn )
          show_count_line( fn, lines, codelines ) if @verbose
          total_lines += lines
          total_code  += codelines
        end
        [ total_lines, total_code ]
      end

    end

  end
end
