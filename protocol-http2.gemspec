
require_relative "lib/protocol/http2/version"

Gem::Specification.new do |spec|
	spec.name = "protocol-http2"
	spec.version = Protocol::HTTP2::VERSION
	
	spec.summary = "A low level implementation of the HTTP/2 protocol."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/protocol-http2"
	
	spec.files = Dir.glob('{lib}/**/*', File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 2.5"
	
	spec.add_dependency "protocol-hpack", "~> 1.4"
	spec.add_dependency "protocol-http", "~> 0.18"
	
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered"
	spec.add_development_dependency "rspec", "~> 3.0"
end
