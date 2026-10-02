# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tempfile"
require "open3"
require "io/wait"

RSpec.describe "CLI" do
  def run_cli(source, *args, env: {})
    output = StringIO.new
    error = StringIO.new
    status = Tempfile.create(["gritz", ".rb"]) do |file|
      file.write(source)
      file.flush
      Gritz::CLI.new(stdout: output, stderr: error, env: env).run([*args, "-C", file.path])
    end
    [status, output.string, error.string]
  end

  it "prints all registered RPC routes" do
    source = "require_relative '#{File.expand_path('../examples/hello/hello_controller', __dir__)}'\nregister_controller HelloController"
    status, output, error = run_cli(source, "routes")
    expect(status).to eq(0), error
    expect(output).to include("SayHello", "ListGreetings", "RecordNames", "Chat", "HelloController")
  end

  it "flushes startup logs to pipes and exits gracefully on TERM" do
    Tempfile.create(["gritz", ".rb"]) do |file|
      file.write("require_relative '#{File.expand_path('../examples/hello/hello_controller',
                                                       __dir__)}'\nregister_controller HelloController\nbind '127.0.0.1:0'\n")
      file.flush
      Open3.popen3("ruby", "exe/gritz", "start", "-C", file.path) do |input, output, error, process|
        input.close
        begin
          expect(output.wait_readable(5)).not_to be_nil
          line = output.gets
          expect(line).to include("listening on 127.0.0.1:")
          address = line.split.last
          stub = Helloworld::Greeter::Stub.new(address, :this_channel_is_insecure)
          reply = stub.say_hello(Helloworld::HelloRequest.new(name: "CLI"), deadline: Time.now + 3)
          expect(reply.message).to eq("Hello, CLI!")
          Process.kill("TERM", process.pid)
          expect(process.join(5)).not_to be_nil
          expect(process.value.success?).to eq(true), error.read
        ensure
          if process.alive?
            Process.kill("KILL", process.pid)
            process.join
          end
        end
      end
    end
  end
end
