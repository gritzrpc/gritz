# frozen_string_literal: true

require "gritz"
$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "hello_services_pb"

class HelloController < Gritz::Controller
  bind Helloworld::Greeter::Service

  def say_hello
    fail!(:invalid_argument, "name is required") if request.message.name.empty?

    Helloworld::HelloReply.new(message: "Hello, #{request.message.name}!")
  end

  def list_greetings
    3.times do |index|
      context.check_deadline!
      context.check_cancelled!
      stream.write(Helloworld::HelloReply.new(message: "Hello, #{request.message.name}! (#{index + 1})"))
    end
  end

  def record_names
    count = request.each_message.count
    Helloworld::HelloReply.new(message: "Recorded #{count} names.", count:)
  end

  def chat
    request.each_message do |message|
      context.check_deadline!
      context.check_cancelled!
      stream.write(Helloworld::HelloReply.new(message: "Hello, #{message.name}!"))
    end
  end
end
