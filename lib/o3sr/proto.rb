# frozen_string_literal: true

# O3sr
module O3sr


  # Events are values fo the type of messages sent.
  module Events
    CONNECT = 1
    DISCONNECT = 2
    TRAFFIC = 3
  end

  # The message protocol.
  # +ver+:: The version.
  # +id+:: The channel id.
  # +type+:: The message type, or event.
  # +data+:: Optional data. This may be "" or nil.
  Message = Struct.new("Message", :ver, :id, :type, :data)

  # Functions to maniuplate messges being sent or received over a socket.
  module MessageProtocol
    MAX_LEN = 1024000
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

    # Parses the bytes. Returns [msg, remaining_bytes] or [ nil, bytes ].
    # Throws Version exception if the version does not match.
    def self.parse(bytes)
      # Not enough to parse the header.
      return [nil, bytes] if bytes.length < 16

      ver, id, type, data_len = bytes.unpack(@header)

      raise "Version is not 1." unless ver == 1

      data_remaining = nil
      if data_len.positive? 
        if data_len + 16 > bytes.length
          # Partial message. Wait.
          [ nil, bytes ]
        else
          data = bytes[16...data_len+16]
          data_remaining = bytes[16+data_len...]
          [ Message.new(ver, id, type, data), data_remaining ]
        end
      else
        data_remaining = bytes[16...]
        [ Message.new(ver, id, type, data), data_remaining ]
      end
    end
  end
end
