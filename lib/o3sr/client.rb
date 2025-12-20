# frozen_string_literal: true

require "socket"
require_relative "proto"
require_relative "logger"

module O3sr
  # Client connects to a Mux port and exchanges messages.
  class Client
    def initialize(host, port, dst_host, dst_port)
      @host = host
      @port = port
      @dst_host = dst_host
      @dst_port = dst_port
      @logger = O3sr::Logger.new("client").with_pid

      # Map of client IDs to sockets.
      @client_socks = {}

      # Map of client sockets to IDs.
      @client_ids = {}

      # For partially received messages from the muxer.
      @msg = nil
    end

    def connect_mux
      loop do
        begin
          @logger.info("Client connecting to #{@host}:#{@port}...")
          @mux = TCPSocket.new @host, @port
          @logger.info("Client connected!")
          return
        rescue => e
          return unless @running
          @logger.error("Client failed to connect (retry in 5 seconds). #{e}")
          sleep(5)
        end
      end
    end

    def start
      @running = true
      connect_mux

      while @running
        c = @client_socks.values
        @r = [@mux, *c]
        @w = []
        @e = [@mux, *c]
        @timeout = 5

        @logger.info("Client selecting on #{@r}.")

        arr = IO.select(@r, @w, @e, @timeout)
        next if arr.nil?

        @logger.info("Client got #{arr}.")

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
          connect_mux
        else
          close_client_socket(s)
        end

        return
      end

      return if msg.nil? || msg.empty?

      @logger.info("Client handling message.")

      if s == @mux
        rest = @msg.nil? || @msg.empty? ? msg : @msg + msg
        msgs = []
        loop do
          msg, rest = O3sr::MessageProtocol.parse(rest)
          break if msg.nil?

          if msg.type == O3sr::Events::DISCONNECT
            @logger.info("Client got DISCONNECT for id #{msg.id}.")
            c = @client_socks[msg.id]
            close_client_socket(c) unless c.nil?
            next
          end

          @logger.info("Client got message id #{msg.id} from mux.")
          msgs << msg
        end

        @msg = rest
        send_to_servers(msgs)
      else
        send_to_mux(s, msg)
      end
    end

    def close_client_socket(s)
      s.close
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
        @logger.info("Client sending #{msg.data.length} bytes to downstream #{s}.")
        s.write(msg.data)
      end
    end

    # Create and add a connection.
    def add_connection(id)
      @logger.info("Establishing connection with #{@dst_host}:#{@dst_port}.")
      sock = TCPSocket.new(@dst_host, @dst_port)
      @client_ids[sock] = id
      @client_socks[id] = sock
      @logger.info("Added connection for id #{id}.")
      @logger.info("Client IDS #{@client_ids}.")
      @logger.info("Client Socks #{@client_socks}.")
    end

    # Send data we got from the downstream to the client through the muxer.
    def send_to_mux(src, data)
      id = @client_ids[src]

      @logger.return info("Client id for socket #{src} not found.") if id.nil?

      msg = O3sr::Message.new(1, id, O3sr::Events::TRAFFIC, data)
      @logger.info("Client sending #{msg} to mux #{id}.")
      O3sr::MessageProtocol.send(@mux, msg)
    end

    def stop
      @logger.info("Stopping.")
      @running = false
    end
  end
end
