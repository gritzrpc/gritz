# frozen_string_literal: true

require "gritz"
$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "hello_services_pb"

stub = Helloworld::Greeter::Stub.new(ENV.fetch("GRITZ_TARGET", "127.0.0.1:50051"), :this_channel_is_insecure)
names = ARGV.empty? ? %w[Ruby Gritz] : ARGV
requests = names.map { |name| Helloworld::HelloRequest.new(name:) }
deadline = Time.now + 5

puts stub.say_hello(requests.first, deadline:).message
stub.list_greetings(requests.first, deadline:).each { |reply| puts reply.message }
puts stub.record_names(requests, deadline:).message
stub.chat(requests, deadline:).each { |reply| puts reply.message }
