# frozen_string_literal: true

require 'socket'
require_relative 'proto.rb'
require_relative 'logger.rb'

module O3sr
  # Matcher is a class that listens on two ports.
  # Connections on the mux port go to the mux pool of connections.
  # The mux pool gets assigned new clients that com in on the server port.
  # Traffic over the server port is muxed through the mux sockets.
  class Matcher
    def initialize(mux_port = 6543, server_port = 6544)
      @mux_port = mux_port
      @server_port = server_port
      @current_id = 1
      # Client connections when there are no mux sockets.
      @client_needs_assignment = {}

      # Mux sockets.
      @muxes = []
      @running = false
      @logger = O3sr::Logger.new("matcher").with_pid

      # Map of client ids to mux and client sockets.
      # id => { client:, mux: }
      @clients = {}

      # Partial messages indexed by socket.
      @msgs = {}
    end

    def start()
      @mux_server = TCPServer.new('0.0.0.0', @mux_port)
      @server = TCPServer.new('0.0.0.0', @server_port)

      @logger.info("Starting matcher.")

      @running = true
      while @running do
        clients = @clients.map { |k, v| v[:client] }
        @r = [@server, @mux_server, *@muxes, *clients]
        @w = []
        @e = [@server, @mux_server, *@muxes, *clients]
        @timeout = 5

        @logger.info("Matcher selecting on #{@r}.")
        arr = IO.select(@r, @w, @e, @timeout)
        next if arr.nil?
        @logger.info("Matcher got #{arr}.")

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
            @logger.info("Socket #{readready} is closed.")
            tell_mux_is_closed(readready)
          else
            handle_msg(readready)
          end
        end
      end
    end

    # A client socket is closed and must be removed from the remote muxer.
    def tell_mux_is_closed(client_sock)
      id, c = @clients.find { |k, rec| rec[:client] == client_sock }
      return if c.nil?

      @logger.info("Client socket #{client_sock} id #{id} is closed.")
      O3sr::MessageProtocol.send(
        c[:mux], 
        O3sr::Message.new(1, id, O3sr::Events::DISCONNECT, nil)
      )

      @clients.delete(id)
    end

    def close_muxer_and_clients(mux)
      # Remove this from the muxers.
      @muxes.delete(mux)

      # Close all related clients and remove them.
      @clients.delete_if do |k, val|
        @logger.info("Closing client #{k} due to muxer close.")
        val[:client].close
        true
      end
    end

    def err_mux(s)
      @logger.info("Mux #{s} is closing due to error.")
      @clients.delete_if do |id, rec|
        if rec[:mux] == s
          @logger.info("Client #{id} closing because associated mux #{s} is closed.")
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
      @logger.info("Client #{client_id} errored.")
    end

    def handle_msg(s)
      b = begin
        s.read_nonblock(O3sr::MessageProtocol::MAX_LEN)
      rescue EOFError => e
        if not @muxes.member? s
          # Client socket closed. Tell the muxer it is closed.
          tell_mux_is_closed(s)
        else
          # The mux closed. CLOSE all clients. Why close? Their TCP is half way in a conversation.
          close_muxer_and_clients(s)
        end

        return
      end

      @logger.info("Matcher recv from #{s}.")

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
      rest = @msgs[s].nil? ? b : @msgs[s] + b

      # From this buffer, build up all the available messages.
      # This will typically be 1, but could be many!
      msgs = []
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
        c[:client].write(msg.data)
      end
    end

    # Messages from the client to the muxer.
    def send_messages_from_client(socket, data)
      id, c = @clients.find { |k, v| v[:client] == socket }
      return if c.nil?

      @logger.info("Sending msg id #{id} over socket #{socket} to mux.")

      msg = O3sr::Message.new(1, id, O3sr::Events::TRAFFIC, data)
      O3sr::MessageProtocol.send(c[:mux], msg)
    end

    def accept_mux(mux)
      s = mux.accept
      @logger.info("Matcher accepted new mux.")
      @muxes << s
    end

    def accept_server(server)
      s = server.accept
      @logger.info("Matcher accepted new client #{@current_id} to socket #{s}.")
      @client_needs_assignment[@current_id] = s
      @current_id+=1
    end

    def map_clients
      return if @muxes.empty?

      @client_needs_assignment.delete_if do |client_id, socket|
        @logger.info("Matcher mapping client #{client_id} to a mux.")
        @clients[client_id] = {
          mux: @muxes[rand(@muxes.length)],
          client: socket,
        }
        @logger.info("Matcher clients is #{@clients}.")
        true
      end
    end

    def stop()
      @logger.info("Stopping.")
      @running = false
    end
  end
end

