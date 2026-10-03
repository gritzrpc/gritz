# frozen_string_literal: true

require "fileutils"
require "cgi"
require "pathname"
require "yard"

source_root = File.expand_path("../..", __dir__)
repos = %w[gritz gritz-core gritz-native gritz-otel gritz-rails gritz-async]
Dir.chdir(File.expand_path("..", __dir__))
input = "tmp/docs-input"
output = "doc"
FileUtils.mkdir_p(input)
FileUtils.rm_rf(output)

files = repos.flat_map do |repo|
  root = File.join(source_root, repo)
  abort "Missing sibling checkout: #{root}" unless File.directory?(File.join(root, "lib"))

  Dir["#{root}/README.md", "#{root}/docs/guides/*.md", "#{root}/docs/*.md"]
end
pages = files.to_h do |path|
  repo = Pathname.new(path).relative_path_from(Pathname.new(source_root)).each_filename.first
  name = path == File.join(source_root, "gritz/README.md") ? "README" : "#{repo}-#{File.basename(path, '.md')}"
  [path, name]
end
pages.each do |path, name|
  text = File.read(path).gsub(/\]\(([^)]+)\)/) do |match|
    link = Regexp.last_match(1)
    next match if link.match?(/\A(?:[a-z]+:|#)/i)

    relative, fragment = link.split("#", 2)
    target = File.expand_path(relative, File.dirname(path))
    href = if pages.key?(target)
             pages[target] == "README" ? "index.html" : "file.#{pages[target]}.html"
           else
             parts = Pathname.new(target).relative_path_from(Pathname.new(source_root)).each_filename.to_a
             kind = File.directory?(target) ? "tree" : "blob"
             "https://github.com/gritzrpc/#{parts.shift}/#{kind}/main/#{parts.join('/')}"
           end
    "](#{href}#{"##{fragment}" if fragment})"
  end
  File.write(File.join(input, "#{name}.md"), text)
end

# These APIs are generated at runtime; derive their documentation from the same source.
require File.join(source_root, "gritz-core/lib/gritz/core")
settings = Gritz::Configuration::DEFAULTS.keys
dynamic = +"module Gritz\n  class Configuration\n"
(settings + %i[controllers middleware preload_app metrics_recorder_factory]).each do |name|
  dynamic << "    # @api public\n    attr_accessor :#{name}\n"
end
dynamic << "  end\n  class DSL\n"
settings.each { |name| dynamic << "    # @api public\n    def #{name}(value); end\n" }
Gritz::Configuration::HOOKS.each { |name| dynamic << "    # @api public\n    def #{name}(&block); end\n" }
dynamic << "  end\n  module Errors\n"
Gritz::Errors::CODES.each do |code|
  name = code.to_s.split("_").map(&:capitalize).join
  dynamic << "    # Canonical #{code} status.\n    # @api public\n    class #{name} < Gritz::Error; end\n"
end
dynamic << "  end\nend\n"
generated = File.join(input, "dynamic_api.rb")
File.write(generated, dynamic)

sources = repos.flat_map { |repo| Dir[File.join(source_root, repo, "lib/**/*.rb")] }
sources.reject! { |path| path.include?("/lib/grpc/") || path.include?("/templates/") }
YARD::CLI::Yardoc.run("--api", "public", "--no-private", "--no-save", "--no-cache", "--no-yardopts", "--no-stats",
                      "--markup", "markdown", "--title", "Gritz documentation", "--readme", "#{input}/README.md",
                      "--output-dir", output, *sources, generated, "-", *pages.values.map { |name| "#{input}/#{name}.md" })

expected = pages.values.map { |name| name == "README" ? "index.html" : "file.#{name}.html" }
expected.push("Gritz/Controller.html", "Gritz/Configuration.html", "Gritz/Client.html", "Gritz/Otel.html", "Gritz/Rails.html",
              "Gritz/Errors/InvalidArgument.html")
expected.each { |page| abort "Missing documentation page: #{page}" unless File.file?(File.join(output, page)) }
abort "Public API navigation is empty" unless File.read(File.join(output, "class_list.html")).include?("Controller")
Dir["#{output}/**/*.html"].each do |page|
  File.read(page).scan(/(?:href|src)="([^"]+)"/).flatten.each do |href|
    next if href.match?(%r{\A(?:[a-z]+:|//|#)}i)

    path = CGI.unescapeHTML(href).split(/[?#]/).first
    next if !path || path.empty?

    abort "Broken documentation link: #{page} -> #{href}" unless File.exist?(File.expand_path(path, File.dirname(page)))
  end
end
public_api = YARD::Registry.all.select do |object|
  object.tag(:api)&.text == "public" && (object.type != :method || object.visibility == :public)
end
inventory = public_api.map { |object| "#{object.path}#{" #{object.signature}" if object.type == :method}" }.sort
File.write(File.join(output, "public-api.txt"), "#{inventory.join("\n")}\n")
File.write(File.join(output, ".nojekyll"), "")
puts "Verified #{expected.size} documentation pages and public API navigation"
