
require_relative "lib/protocol/http2/version"

Gem::Specification.new do |spec|
	spec.name          = "protocol-http2"
	spec.version       = Protocol::HTTP2::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	
	spec.summary       = "A low level implementation of the HTTP/2 protocol."
	spec.homepage      = "https://github.com/socketry/protocol-http2"
	spec.license       = "MIT"
	
	spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
		`git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
	end
	
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.require_paths = ["lib"]
	
	spec.add_dependency "protocol-hpack", "~> 1.0"
	spec.add_dependency "protocol-http"
	
	spec.add_development_dependency "covered"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "rake", "~> 10.0"
	spec.add_development_dependency "rspec", "~> 3.0"
end
