# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "io/stream/shim/buffered"

describe IO do
	let(:io) {IO.new(IO.sysopen("/dev/null", "w"))}
	
	it "should be buffered by default" do
		expect(io).to be(:buffered?)
	end
	
	it "should be able to set buffering" do
		io.buffered = false
		
		expect(io).not.to be(:buffered?)
	end
end

describe TCPSocket do
	let(:client) {@client = TCPSocket.new("localhost", @server.local_address.ip_port)}
	
	def before
		@server = TCPServer.new("localhost", 0)
	end
	
	def after(error = nil)
		@server.close
		@client&.close
		
		super
	end
	
	it "should not be buffered by default" do
		expect(client).not.to be(:buffered?)
	end
	
	it "should be able to unset buffering" do
		client.buffered = false
		expect(client).not.to be(:buffered?)
	end
	
	it "should be able to set buffering" do
		client.buffered = true
		expect(client).to be(:buffered?)
	end
end

describe UNIXSocket do
	let(:sockets) {UNIXSocket.pair}
	let(:client) {sockets[0]}
	let(:server) {sockets[1]}
	
	def after(error = nil)
		client.close
		server.close
		
		super
	end
	
	it "should not be buffered by default" do
		expect(client).not.to be(:buffered?)
	end
	
	it "should be able to unset buffering" do
		client.buffered = false
		expect(client).not.to be(:buffered?)
	end
	
	it "should be able to set buffering" do
		client.buffered = true
		expect(client).to be(:buffered?)
	end
end

describe StringIO do
	let(:io) {StringIO.new}
	
	it "should not be buffered by default" do
		expect(io).not.to be(:buffered?)
	end
	
	it "is always unbuffered" do
		io.buffered = true
	
		expect(io).not.to be(:buffered?)
	end
end
