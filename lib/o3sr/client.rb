# frozen_string_literal: true

require 'socket'
require_relative 'proto.rb'

module O3sr
  # Client connects to a Mux port and exchanges messages.
  class Client
    def initialize(host, port, dst_host, dst_port)
      @host = host
      @port = port
      @dst_host = dst_host
      @dst_port = dst_port
    end

    def start
      sock = TCPSocket.new @host, @port
    end
  end
end