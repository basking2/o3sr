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
      @server_port = @mux_port+1
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
      @mux_server = TCPServer.new('0.0.0.0', @mux_port)
      @server = TCPServer.new('0.0.0.0', @server_port)

      info("Starting matcher.")

      @running = true
      while @running do
        clients = @clients.map { |k, v| v[:client] }
        @r = [@server, @mux_server, *@muxes, *clients]
        @w = []
        @e = [@server, @mux_server, *@muxes, *clients]
        @timeout = 5

        info("Matcher selecting on #{@r}.")
        arr = IO.select(@r, @w, @e, @timeout)
        next if arr.nil?
        info("Matcher got #{arr}.")

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
          if readready == @server
            # Adding to clients!
            accept_server(@server)
            map_clients
          elsif @mux_server == readready
            # Adding to muxes!
            accept_mux(@mux_server)
            map_clients
          elsif readready.closed?
            info("Socket #{readready} is closed.")
            tell_mux_is_closed(readready)
          else
            handle_msg(readready)
          end
        end
      end
    end

    def tell_mux_is_closed(client_sock)
      id, c = @clients.find { |k, rec| rec[:client] == client_sock }
      return if c.nil?

      O3sr::MessageProtocol.send(
        c[:mux], 
        O3sr::MessageProtocol.new(1, id, O3sr::MessageProtocol::DISCONNECT, nil)
      )

      @clients.delete(id)
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
      info "Matcher recv from #{s}."

      return if b.empty?

      # Now that we have a buffer, did this come from a mux socket
      # or a server socket? Server sockets have raw protocol bytes while
      # mux sockets have messages.
      if not @muxes.member? s
        # Getting a request to send over a mux.
        send_messages_from_client(s, b)
        return
      end


      # Get any partial message from the @msgs store.
      if @msgs[s]
        b = @msgs[s] + b
      end

      # From this buffer, build up all the available messages.
      # This will typically be 1, but could be many!
      msgs = []
      rest = b
      loop do
        msg, rest = O3sr::MessageProtocol.parse(rest)
        break if msg.nil?
        msgs << msg
      end

      if rest.nil? or rest.length == 0
        @msgs.delete(s) 
      else
        @msgs[s] = rest
      end

      # Getting a response to send to a client.
      send_messages_from_mux(msgs)
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
    def send_messages_from_client(socket, data)
      id, c = @clients.find { |k, v| v[:client] == socket }
      return if c.nil?

      msg = O3sr::Message.new(1, id, O3sr::Events::TRAFFIC, data)
      O3sr::MessageProtocol.send(c[:mux], msg)
    end

    def accept_mux(mux)
      s = mux.accept
      info("Accpeted new mux.")
      @muxes << s
    end

    def accept_server(server)
      s = server.accept
      info("Accepted new client.")
      @client_needs_assignment[@current_id] = s
      @current_id+=1
    end

    def map_clients
      return if @muxes.empty?

      @client_needs_assignment.delete_if do |client_id, socket|
        @clients[client_id] = {
          mux: @muxes[rand(@muxes.length)],
          client: socket,
        }
        true
      end
    end

    # Cheap logging stuff.

    def info(s)
      puts("#{Process.pid} - #{s}")
    end
  end
end

