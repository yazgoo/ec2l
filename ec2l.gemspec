# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ec2l/version'

Gem::Specification.new do |spec|
  spec.name          = "ec2l"
  spec.version       = Ec2l::VERSION
  spec.authors       = ["yazgoo"]
  spec.email         = ["yazgoo@github.com"]
  spec.summary       = "a convenience wrapper for EC2 apis"
  spec.description   = spec.summary
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_runtime_dependency "amazon-ec2"
  spec.add_runtime_dependency "awesome_print"
  spec.add_runtime_dependency "pry"
end
