# frozen_string_literal: true

require "o3sr/proto"

require "stringio"

# rubocop:disable Metrics/BlockLength
RSpec.describe O3sr do
  it "can make a message" do
    m = O3sr::Message.new(1, 2, 3, "hi")
    s = StringIO.new
    O3sr::MessageProtocol.send(s, m)
    s.rewind
    m2 = O3sr::MessageProtocol.recv(s)

    expect(m2.id).to eq(m.id)
    expect(m2.type).to eq(m.type)
    expect(m2.ver).to eq(m.ver)
    expect(m2.data).to eq(m.data)
  end

  it "can make a message with nil data" do
    m = O3sr::Message.new(1, 2, 3, nil)
    s = StringIO.new
    O3sr::MessageProtocol.send(s, m)
    s.rewind
    m2 = O3sr::MessageProtocol.recv(s)

    expect(m2.id).to eq(m.id)
    expect(m2.type).to eq(m.type)
    expect(m2.ver).to eq(m.ver)
    expect(m2.data).to eq("")
  end

  it "can make a message with zero data" do
    m = O3sr::Message.new(1, 2, 3, "")
    s = StringIO.new
    O3sr::MessageProtocol.send(s, m)
    s.rewind
    m2 = O3sr::MessageProtocol.recv(s)

    expect(m2.id).to eq(m.id)
    expect(m2.type).to eq(m.type)
    expect(m2.ver).to eq(m.ver)
    expect(m2.data).to eq(m.data)
  end

  it "can parse a message" do
    m = O3sr::Message.new(1, 2, 3, "hi")
    s = StringIO.new
    O3sr::MessageProtocol.send(s, m)
    s.rewind
    b = s.read
    m2, rest = O3sr::MessageProtocol.parse(b)

    expect(m2.id).to eq(m.id)
    expect(m2.type).to eq(m.type)
    expect(m2.ver).to eq(m.ver)
    expect(m2.data).to eq(m.data)
  end

  it "can parse zero length a message" do
    m = O3sr::Message.new(1, 2, 3, nil)
    s = StringIO.new
    O3sr::MessageProtocol.send(s, m)
    s.rewind
    b = s.read
    m2, rest = O3sr::MessageProtocol.parse(b)

    expect(m2.id).to eq(m.id)
    expect(m2.type).to eq(m.type)
    expect(m2.ver).to eq(m.ver)
    expect(m2.data).to eq(m.data)
  end

  # rubocop:enable Metrics/BlockLength
end
