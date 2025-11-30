# frozen_string_literal: true

require "o3sr/proto"
require "o3sr/matcher"
require "o3sr/client"

require 'net/http'

RSpec.describe O3sr::Matcher do
  matcher = nil
  it "starts matcher" do
    matcher = O3sr::Matcher.new
    Thread.new { matcher.start }
    sleep 1
  end

  client = nil
  it "starts a client" do
    client = O3sr::Client.new("localhost", 6543, "www.google.com", 443)
    Thread.new { client.start }
    sleep 1
  end

  it "relays traffic" do
    http = Net::HTTP.new("localhost", 6544)
    http.use_ssl = true
    req = Net::HTTP::Get.new("/")
    req['Host'] = 'www.google.com'
    puts "Sending request"
    resp = http.request req
    puts "Got response"
    puts resp
    puts resp.body
  end
end