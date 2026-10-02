# frozen_string_literal: true

require_relative "../hello_controller"

workers 0
threads 16
bind "127.0.0.1:50051"
register_controller HelloController
