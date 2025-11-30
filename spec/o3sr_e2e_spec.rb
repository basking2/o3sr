# frozen_string_literal: true

require "o3sr/proto"
require "o3sr/matcher"
require "o3sr/client"

require 'net/http'

RSpec.describe O3sr::Matcher do

  before do
    skip "See e2d_www version."
  end

  matcher = nil
  it "starts matcher" do
    matcher = O3sr::Matcher.new
    Thread.new { matcher.start }
    sleep 1
  end

  client = nil
  it "starts a client" do
    #client = O3sr::Client.new("localhost", 6543, "www.google.com", 443)
    client = O3sr::Client.new("localhost", 6543, "localhost", 6545)
    Thread.new { client.start }
    sleep 1
  end

  it "puts up a test server on 6545" do
    server = TCPServer.new('localhost', 6545)
    Thread.new do
      loop do
        sock = server.accept
        Thread.new(sock) do |s|
          b = s.readpartial(4096)
          puts "Echo server got #{b.length} bytes. Echoing back."
          s.write b
          s.close
        end
      end
    end
    sleep 1
  end

  it "echo server works" do
    sock = TCPSocket.new('localhost', 6544)
    msg = "Hello, world!"
    sock.write msg
    resp = sock.readpartial(4096)
    expect(resp).to eq(msg)
    sock.close
    client.stop
    matcher.stop
  end

  #it "relays traffic" do
  #  http = Net::HTTP.new("localhost", 6544)
  #  http.use_ssl = true
  #  req = Net::HTTP::Get.new("/")
  #  req['Host'] = 'www.google.com'
  #  puts "Sending request"
  #  resp = http.request req
  #  puts "Got response"
  #  puts resp
  #  puts resp.body
  #end
end