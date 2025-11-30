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

      # Map of client IDs to sockets.
      @client_socks = {}

      # Map of client sockets to IDs.
      @client_ids = {}

      # For partially received messages from the muxer.
      @msg = nil
    end

    def start
      @running = true
      info("Client connecting to #{@host}:#{@port}...")
      @mux = TCPSocket.new @host, @port
      info("Client connected!")

      while @running do
        c = @client_socks.values
        @r = [@mux, *c]
        @w = []
        @e = [@mux, *c]
        @timeout = 5

        info("Client selecting on #{@r}.")

        arr = IO.select(@r, @w, @e, @timeout)
        next if arr.nil?

        info("Client got #{arr}.")

        arr[2].each do |r|
        end

        arr[0].each do |r|
          handle_msg(r)
        end
      end
    end

    def handle_msg(s)
      # Get some data.
      msg = begin
        s.read_nonblock(O3sr::MessageProtocol::MAX_LEN)
      rescue EOFError => e
        if s == @mux
          # Mux socket closed. We're done. Exit.
          raise e
        end

        close_client_socket(s)
        return

      end

      return if msg.nil? or msg.length == 0

      info("Client handling message.")

      if s == @mux
        rest = (@msg.nil? or @msg.length == 0) ? msg : @msg + msg
        msgs = []
        loop do
          msg, rest = O3sr::MessageProtocol.parse(rest)
          break if msg.nil?

          if msg.type == O3sr::Events::DISCONNECT
            c = @client_socks[msg.id]
            return if c.nil?
            close_client_socket(c)
            return
          end

          msgs << msg
        end

        @msg = rest
        send_to_servers(msgs)
      else
        send_to_mux(s, msg)
      end
    end

    def close_client_socket(s)
      s.close()
      id = @client_ids.delete(s)
      @client_socks.delete(id)
    end

    # Send data we got from the muxer to the servers.
    def send_to_servers(msgs)
      msgs.each do |msg|
        id = msg.id
        s = @client_socks[id]
        add_connection(id) if s.nil?
        s = @client_socks[id]
        info("Client sending #{msg.data.length} bytes to downstream #{s}.")
        s.write(msg.data)
      end
    end

    # Create and add a connection.
    def add_connection(id)
      info("Establishing connection with #{@dst_host}:#{@dst_port}.")
      sock = TCPSocket.new(@dst_host, @dst_port)
      @client_ids[sock] = id
      @client_socks[id] = sock
      info("Added connection for id #{id}.")
    end

    # Send data we got from the downstream to the client through the muxer.
    def send_to_mux(src, data)
      id = @client_ids[src]

      return info("Client id for socket #{src} not found.") if id == nil

      msg = O3sr::Message.new(1, id, O3sr::Events::TRAFFIC, data)
      info("Client sending #{msg} to mux #{id}.")
      O3sr::MessageProtocol.send(@mux, msg)
    end
  
    def info(s)
      puts("#{Process.pid} - #{s}")
    end

    def stop()
      @running = false
    end
  end
end