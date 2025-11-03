# frozen_string_literal: true

require_relative "lib/memory/profiler/version"

Gem::Specification.new do |spec|
	spec.name = "memory-profiler"
	spec.version = Memory::Profiler::VERSION
	
	spec.summary = "Efficient memory allocation tracking with call path analysis."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/memory-profiler"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/memory-profiler/",
		"source_code_uri" => "https://github.com/socketry/memory-profiler",
	}
	
	spec.files = Dir["{context,ext,lib}/**/*", "*.md", base: __dir__]
	spec.require_paths = ["lib"]
	
	spec.extensions = ["ext/extconf.rb"]
	
	spec.required_ruby_version = ">= 3.3"
end
