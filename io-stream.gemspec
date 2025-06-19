# frozen_string_literal: true

require_relative "lib/io/stream/version"

Gem::Specification.new do |spec|
	spec.name = "io-stream"
	spec.version = IO::Stream::VERSION
	
	spec.summary = "Provides a generic stream wrapper for IO instances."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/io-stream"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/io-stream",
		"source_code_uri" => "https://github.com/socketry/io-stream.git",
	}
	
	spec.files = Dir.glob(["{lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
end
