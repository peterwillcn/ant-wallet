# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ant/wallet/version'

Gem::Specification.new do |spec|
  spec.name          = "ant-wallet"
  spec.version       = Ant::Wallet::VERSION
  spec.authors       = ["tianxiaobo"]
  spec.email         = ["peterwillcn@gmail.com"]

  spec.summary       = %q{AntShares Wallet}
  spec.description   = %q{This is a ruby library for ant shares with the Wallet}
  spec.homepage      = "https://github.com/peterwillcn/ant-wallet"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_dependency "scrypt", '~> 3.0', '>= 3.0.3'
  spec.add_dependency 'sqlite3', '~> 1.3', '>= 1.3.12'
  spec.add_dependency 'faraday', '~> 0.9.2'
  spec.add_dependency 'multi_json', '>= 1.1.0'
  spec.add_dependency "thin", "~> 1.7"
  spec.add_dependency 'highline', '~> 1.7', '>= 1.7.8'

end
