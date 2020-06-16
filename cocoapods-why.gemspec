# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods_why.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-why'
  spec.version       = CocoaPodsWhy::VERSION
  spec.authors       = ['Trevor Harmon']
  spec.email         = ['trevorh@squareup.com']
  spec.license       = 'MIT'

  spec.summary       = 'Shows why one CocoaPod depends on another'
  spec.description   = 'In CocoaPods projects with a large number of dependencies, the reason why a particular pod has a transitive dependency on some other pod (possibly one you do not want) is not always clear. This plugin adds a "why" command that shows all paths between the two pods, showing exactly how the two pods are related.'
  spec.homepage      = 'https://github.com/square/cocoapods-why'

  spec.files         = Dir['*.md', 'lib/**/*', 'LICENSE']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'

  spec.add_dependency 'cocoapods', '~> 1.0'
  spec.add_dependency 'rgl', '~> 0.5'
end
