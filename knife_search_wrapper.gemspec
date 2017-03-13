# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knife_search_wrapper/version'

Gem::Specification.new do |spec|
  spec.name          = 'knife_search_wrapper'
  spec.version       = Knife::Search::Wrapper::VERSION
  spec.authors       = ['Chris Sullivan']
  spec.email         = ['email-blocked']
  spec.date          = '2017-103-13'

  spec.summary       = 'Sort for knife search'
  spec.description   = 'Add basic sorting on client side for chef search'
  spec.homepage      = 'https://github.com/chrisgit/knife-search_wrapper'
  spec.license       = 'MIT'

  spec.files         = Dir['{lib}/**/*', 'README*', 'LICENSE*']
  spec.require_paths = ['lib']

end
