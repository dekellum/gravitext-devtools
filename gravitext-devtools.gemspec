# -*- ruby -*-

gem 'rjack-tarpit', '~> 2.0.a'
require 'rjack-tarpit/spec'

$LOAD_PATH.unshift( File.join( File.dirname( __FILE__ ), 'lib' ) )

require 'gravitext-devtools/base'

RJack::TarPit.specify do |s|

  s.version  = Gravitext::DevTools::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'rainbow',               '~> 1.1'
  s.depend 'hooker',                '~> 1.0.0'

end
