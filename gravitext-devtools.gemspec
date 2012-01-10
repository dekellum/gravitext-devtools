# -*- ruby -*-

gem 'rjack-tarpit', '~> 2.0'
require 'rjack-tarpit/spec'

RJack::TarPit.specify do |s|
  require 'gravitext-devtools/base'

  s.version = Gravitext::DevTools::VERSION

  s.add_developer( 'David Kellum', 'dek-oss@gravitext.com' )

  s.depend 'rainbow',               '~> 1.1'
  s.depend 'hooker',                '~> 1.0.0'
end
