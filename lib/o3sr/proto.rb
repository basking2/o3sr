# frozen_string_literal: true

# O3sr
module O3sr
  # The message protocol.
  Message = Struct.new("Message", :ver, :id, :type, :data)

  # Functions to maniuplate messges being sent or received over a socket.
  module MessageProtocol
    @header = "NNNN"
    @header_and_body = "#{@header}a*"
    def self.mustread(sock, len)
      s = ""
      while len.positive?
        buf = sock.read(len)
        raise "unexpected end of stream" if buf.nil?

        s += buf
        len -= buf.length
      end
      s
    end

    def self.recv(sock)
      ver, id, type, data_len = mustread(sock, 16).unpack(@header)
      raise "Version is not 1." unless ver == 1

      data = data_len.positive? ? mustread(sock, data_len) : ""

      Message.new(ver, id, type, data)
    end

    def self.send(sock, msg)
      len = msg.data.nil? ? 0 : msg.data.length
      data = [msg.ver, msg.id, msg.type, len, msg.data].pack(@header_and_body)
      sock.write(data)
    end
  end
end
