# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'android_ci_helper/version'

Gem::Specification.new do |spec|
  spec.name          = "android_ci_helper"
  spec.version       = AndroidCIHelper::VERSION
  spec.authors       = ["James Tomson"]
  spec.email         = ["jtomson@mdsol.com"]
  spec.summary       = spec.description   = %q{A collection of methods to assist running android emulators in a headless CI environment.}
  spec.description   = spec.summary
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
