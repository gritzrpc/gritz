# frozen_string_literal: true

require_relative "lib/gritz/version"

Gem::Specification.new do |spec|
  spec.name = "gritz"
  spec.version = Gritz::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "A controller-based Ruby gRPC application framework"
  spec.description = "Gritz combines transport-independent controllers, middleware and testing with a gRPC C-core server."
  spec.homepage = "https://github.com/gritzrpc/gritz"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "LICENSE.txt", "CHANGELOG.md"]
  spec.bindir = "exe"
  spec.executables = ["gritz"]
  spec.require_paths = ["lib"]

  spec.add_dependency "gritz-core", Gritz::VERSION
  spec.add_dependency "gritz-native", Gritz::VERSION
end
