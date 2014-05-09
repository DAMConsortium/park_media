# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'park_media/version'

Gem::Specification.new do |spec|
  spec.name          = 'park_media'
  spec.version       = ParkMedia::VERSION
  spec.authors       = ['John Whitson']
  spec.email         = ['john.whitson@gmail.com']
  spec.summary       = %q{A Library and Utilities for Interacting with Park Media}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ''

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'json'
  spec.add_dependency 'xml-simple'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
end
