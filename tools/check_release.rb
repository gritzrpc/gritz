# frozen_string_literal: true

require "open3"
require_relative "../lib/gritz/version"
require_relative "../gems/gritz-core/lib/gritz/core/version"
require_relative "../gems/gritz-grpc/lib/gritz/grpc/version"

versions = [Gritz::VERSION, Gritz::Core::VERSION, Gritz::Grpc::VERSION]
tag = ENV.fetch("GITHUB_REF_NAME", "")
abort "Tag and package version must match (expected v#{Gritz::VERSION})" unless versions.uniq.size == 1 && tag == "v#{versions.first}"

def git!(*)
  output, status = Open3.capture2e("git", *)
  abort output unless status.success?

  output
end

previous = git!("tag", "--list", "v*", "--merged", "HEAD").lines.map(&:strip)
previous = previous.select do |name|
  name.match?(/\Av\d+\.\d+\.\d+\z/) && Gem::Version.new(name.delete_prefix("v")) < Gem::Version.new(Gritz::VERSION)
end.max_by { |name| Gem::Version.new(name.delete_prefix("v")) }
changed = previous ? git!("diff", "--name-only", previous, "HEAD").lines.map(&:strip) : git!("ls-files").lines.map(&:strip)
runtime = changed.any? do |path|
  path.match?(%r{\A(?:lib/|exe/|gems/[^/]+/lib/)}) && !path.end_with?("/version.rb")
end
dependency_change = previous && git!("diff", previous, "HEAD", "--", "*.gemspec").match?(/^[+-]\s*spec\.add_dependency\b/)
abort "No user-facing runtime or dependency changes; do not release documentation-only changes" unless runtime || dependency_change

puts "Release #{tag} validated"
