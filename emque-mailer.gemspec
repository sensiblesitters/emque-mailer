# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'emque/mailer/version'

Gem::Specification.new do |spec|
  spec.name          = "emque-mailer"
  spec.version       = Emque::Mailer::VERSION
  spec.authors       = ["Dan Matthews"]
  spec.email         = ["dan@sensiblesitters.com"]

  spec.summary       = %q{An Emque::Consuming compatible mail class}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/sensiblesitters/emque-mailer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sendgrid-ruby", "0.0.3"
  spec.add_dependency "emque-consuming", "~> 1.0.0.beta1"

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
end
