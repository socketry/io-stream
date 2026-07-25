# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/stream/buffered"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/openssl/verified_certificate_context"
require "sus/fixtures/openssl/valid_certificate_context"

describe IO::Stream::Buffered do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::OpenSSL::VerifiedCertificateContext
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	before do
		listener = TCPServer.new("localhost", 0)
		port = listener.local_address.ip_port
		
		@sockets = [
			TCPSocket.new("localhost", port),
			listener.accept,
		]
		listener.close
		
		client = OpenSSL::SSL::SSLSocket.new(@sockets[0], client_context)
		server = OpenSSL::SSL::SSLSocket.new(@sockets[1], server_context)
		
		client.sync_close = true
		server.sync_close = true
		
		[
			Async {server.accept},
			Async {client.connect},
		].each(&:wait)
		
		@client = IO::Stream::Buffered.wrap(client)
		@server = IO::Stream::Buffered.wrap(server)
	end
	
	after do
		@client&.close
		@server&.close
		@sockets.each{|socket| socket.close unless socket.closed?}
	end
	
	attr :client
	attr :server
	
	it "detects a TLS close notification" do
		closing = reactor.async do
			server.close
		end
		
		@sockets[0].wait_readable(1)
		
		expect(client).not.to be(:readable?)
		closing.wait
	end
	
	it "preserves data consumed by the readability probe" do
		server.write("Hello")
		server.flush
		
		@sockets[0].wait_readable(1)
		
		expect(client).to be(:readable?)
		expect(client.read(5)).to be == "Hello"
	end
end
