# frozen_string_literal: true

require "spec_helper"
require_relative "../examples/hello/hello_controller"

RSpec.describe HelloController do
  it "serves the example's four RPC forms and validates input" do
    Gritz::Testing::Server.start(controllers: [described_class], logger: Logger.new(File::NULL)) do |server|
      stub = Helloworld::Greeter::Stub.new(server.address, :this_channel_is_insecure)
      message = Helloworld::HelloRequest.new(name: "Ruby")
      expect(stub.say_hello(message).message).to eq("Hello, Ruby!")
      expect { stub.say_hello(Helloworld::HelloRequest.new) }.to raise_error(GRPC::InvalidArgument, /name is required/)
      expect(stub.record_names([message, message]).message).to eq("Recorded 2 names.")
      expect(stub.list_greetings(message).count).to eq(3)
      expect(stub.chat([message, message]).map(&:message)).to eq(["Hello, Ruby!", "Hello, Ruby!"])
    end
  end
end
