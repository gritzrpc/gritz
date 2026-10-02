# frozen_string_literal: true

require "rspec/core/rake_task"
require "fileutils"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Build all release packages"
task :build do
  FileUtils.mkdir_p("pkg")
  root = File.expand_path(__dir__)
  %w[gems/gritz-core/gritz-core.gemspec gems/gritz-grpc/gritz-grpc.gemspec gritz.gemspec].each do |path|
    directory = File.dirname(path)
    name = File.basename(path, ".gemspec")
    Dir.chdir(directory) { sh "gem", "build", "--strict", File.basename(path), "--output", "#{root}/pkg/#{name}.gem" }
  end
end

desc "Publish the tagged packages using the workflow's trusted publisher credentials"
task release: :build do
  abort "Use the tag-triggered release workflow" unless ENV["GITHUB_ACTIONS"] == "true" && ENV["GITHUB_REF_TYPE"] == "tag"

  sh "ruby", "tools/check_release.rb"
  %w[gritz-core gritz-grpc gritz].each { |name| sh "gem", "push", "pkg/#{name}.gem" }
end
