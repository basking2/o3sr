# frozen_string_literal: true

require 'socket'
require_relative 'proto.rb'

module O3sr
  # Matcher is a class that listens on two ports.
  # Connections on the mux port go to the mux pool of connections.
  # The mux pool gets assigned new clients that com in on the server port.
  # Traffic over the server port is muxed through the mux sockets.
  class Matcher
    def initialize()
      @mux_port = 6543
      @sever_port = @mux_port+1
      @current_id = 0
      # Client connections when there are no mux sockets.
      @client_needs_assignment = {}

      # Mux sockets.
      @muxes = []
      @running = false

      # Map of client ids to mux and client sockets.
      # id => { client:, mux: }
      @clients = {}

      # Partial messages indexed by socket.
      @msgs = {}
    end

    def start()
      @server = TCPServer.new('0.0.0.0', @server_port)
      @mux_server = TCPServer.new('0.0.0.0', @mux_port)

      info("Starting.")

      @running = true
      while @running do
        @r = [@server, *@muxes]
        @w = []
        @e = [@server, *@muxes]
        @timeout = 2

        arr = IO.select(@r, @w, @e, @timeout)
        next if arr.nil?

        # Handle sockets in error.
        arr[2].each do |err|
          raise "Server socket errored: restart" if err == @server
          if @muxes.member? err
            err_mux(err)
          else
            err_socket(err)
          end
        end

        # Read from readers.
        arr[0].each do |readready|
          if readread == @server
            # Adding to clients!
            accept_server(@server)
            map_clients
          elsif @mux_server == readready
            # Adding to muxes!
            accept_mux(server)
            map_clients
          else
            handle_msg(readready)
          end
        end
      end
    end

    def err_mux(s)
      info("Mux #{s} is closing due to error.")
      @clients.delete_if do |id, rec|
        if rec[:mux] == s
          info("Client #{id} closing because associated mux #{s} is closed.")
          rec[:client].close()
        else
          false
        end
      end
    end

    def err_socket(s)
      # Find the client record for the socket.
      client_id, client_rec = @clients.find { |k, v| v[:client]==s}
      @clients.delete(client_id)
      client_rec[:client].close()
      info("Client #{client_id} errored.")
    end

    def handle_msg(s)
      b = s.read_nonblock(O3sr::MessageProtocol::MAX_LEN)

      return if b.empty?

      # Get any partial message from the @msgs store.
      if @msgs[s]
        b = @msgs[s] + b
      end

      # From this buffer, build up all the available messages.
      # This will typically be 1, but could be many!
      msgs = []
      loop do
        msg, rest = O3sr::MessageProtocol.parse(b)
        break if msg.nil?
        msgs << msg
      end

      if rest.nil? or rest.length == 0
        @msgs.delete(s) 
      else
        @msgs[s] = rest
      end

      # We got a message from the socket! Now... where do we send it?

      if @muxes.member? s
        # Getting a response to send to a client.
        send_messages_from_mux(msgs)
      else
        # Getting a request to send over a mux.
        send_messages_from_client(msgs)
      end
    end

    # Messages from the muxer to the client.
    def send_messages_from_mux(msgs)
      msgs.each do |msg|
        c = @clients[msg.id]
        next if c.nil?
        O3sr::MessageProtocol.send(c[:client], msg)
      end
    end

    # Messages from the client to the muxer.
    def send_messages_from_client(msgs)
      msgs.each do |msg|
        c = @clients[msg.id]
        next if c.nil?
        O3sr::MessageProtocol.send(c[:mux], msg)
      end
    end

    def accept_mux(mux)
      info("Accpeting new mux.")
      s = server.accept
      @muxes << s
    end

    def accept_server(server)
      info("Accpeting new client..")
      s = mux.accept
      @client_needs_assignment[@currentid] = s
      @current_id+=1
    end

    def map_clients
      return if @muxes.empty?

      @client_needs_assignment.each do |client_id, socket|
        @clients[client_id] = {
          mux: @muxes[rand(@muxes.length)],
          client: socket,
        }
      end
    end

    # Cheap logging stuff.

    def info(s)
      puts(s)
    end
  end
end

