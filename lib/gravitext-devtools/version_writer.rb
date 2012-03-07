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


      class HistoryFile
      end

      def initialize

        @local_dep_prefix = nil
        @git_lister = GitFileLister.new

        @patterns = {
          :history => [ /History\./,
                        /^=== ([0-9a-z.]+) \((TBD|[0-9\-]+)\)/ ],
          :pom     => [ /pom\.xml$/,
                        /<version>([0-9a-z.]+)<\/version>/ ],
          :rb      => [ /(version|base)\.rb$/,
                        /VERSION\s*=\s*['"]([0-9a-z.]+)['"]/ ],
          :init    => [ /init\//,
                        /^gem.+,\s*['"]=\s*([0-9a-z.]+)['"]/ ],
          :gemspec => [ /\.gemspec$/,
                        /RJack::TarPit\.specify/ ]
        }

        Hooker.apply( [ :gt, :version ], self )
      end

      def parse_options( args = ARGV )
        @git_lister.parse_options( args ) do |opts|
          opts.banner = "Usage: gt-version [options] dir|files ..."
          opts.on( "-v", "--version V", "Specify new version", String ) do |v|
            @version = v
          end
          opts.on( "-d", "--depend-prefix P",
                   "Also adjust local dependencies with prefix" ) do |p|
            @local_dep_prefix = p
          end
        end
      end

      def run( args = ARGV )
        parse_options( args )

        args.each do |fname|
          process( fname )
        end
      end

      def process( fname )
        type, (_,vline) = @patterns.find { |_,(fp,_)| fname =~ fp }
        return false unless type
        lines = IO.readlines( fname )
        first_match = true
        lines.each_index do |i|
          line = lines[i]
          if line =~ vline
            case type
            when :history
              if $2 == 'TBD'
                lines[i] = "=== #{$1} (#{release_date})"
              else
                lines.insert( i, [ "=== #{@version} (TBD)", '' ] )
              end
            when :pom
              lines[i] = line.sub( /^(\s*<version>)([0-9a-z.]+)(<\/version>)/,
                                   "\\1#{@version}\\3" )
              adjust_pom_local( lines, i+1 )
            when :rb
              lines[i] = line.sub( /^(\s*VERSION\s*=\s*['"])([0-9a-z.]+)/,
                                   "\\1#{@version}" )
            when :init
              lines[i] = line.sub( /^(gem.+,\s*['"]=\s*)([0-9a-z.]+)/,
                                   "\\1#{@version}" )
            when :gemspec
              adjust_gemspec_local( lines, i+1 )
            end
            break
          end
        end
        rewrite_file( fname, lines )
        true
      end

      def adjust_pom_local( lines, start )
        parent = false
        local = false
        lines.each_index do |i|
          next unless i >= start
          line = lines[i]
          case line
          when /<parent>/
            local = true
            parent = true
          when /<\/parent>/
            local = false
            parent = false
          when /<artifactId>/
            local = ( line =~ /<artifactId>\s*#{@local_dep_prefix}/ )
          when /<version>([\[\]\(\)0-9a-z.,]+)(<\/version>)/
            if local
              if parent
                lines[i] = line.sub( /^(\s*<version>)([0-9a-z.]+)/,
                                     "\\1#{@version}" )
              else
                lines[i] = line.sub( /^(\s*<version>)([\[\]\(\)0-9a-z.,]+)/,
                                     "\\1#{maven_version_range}" )
              end
            end
          when /<\/dependencies>/
            break
          end
        end
      end

      def adjust_gemspec_local( lines, start )
        parent = false
        local = false
        lines.each_index do |i|
          next unless i >= start
          line = lines[i]
          if line =~ /\.depend.+['"]#{@local_dep_prefix}/
            lines[i] = line.sub( /(\.depend.*,\s*['"])([^'"]+)(['"])/,
                                 "\\1#{gem_version_range}\\3" )
          end
        end
      end

      def release_date
        Time.now.strftime( "%Y-%-m-%-d" )
      end

      def rewrite_file( file, lines )
        open( file, "w" ) { |fout| fout.puts( lines ) }
      end

      def maven_version_range
        minor_v = @version =~ /^(\d+\.\d+)/ && $1
        "[#{@version},#{minor_v}.999)"
      end

      def gem_version_range
        "~> #{@version}"
      end

    end

  end
end
