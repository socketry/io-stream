#!/usr/bin/env ruby

require 'async'
require 'openssl'
require 'io/endpoint/ssl_endpoint'
require 'io/stream'
require 'localhost'

authority = Localhost::Authority.fetch

endpoint = IO::Endpoint.tcp('localhost', 12345)
server_endpoint = IO::Endpoint::SSLEndpoint.new(endpoint, ssl_context: authority.server_context)
client_endpoint = IO::Endpoint::SSLEndpoint.new(endpoint, ssl_context: authority.client_context)

message = "0123456789"

Async do
	server_task = Async do
		$stderr.puts "Server listening on #{server_endpoint}"
		server_endpoint.accept do |peer|
			$stderr.puts "Accepted connection from: #{peer.remote_address.inspect}"
			
			stream = IO::Stream(peer)
			1000.times do
				1000.times do
					stream.write(message)
				end
				
				stream.flush
			end
		ensure
			peer.close
		end
	end
	
	100.times do
		$stderr.puts "Client connecting to #{client_endpoint}"
		peer = client_endpoint.connect
		$stderr.puts "Connected to: #{peer.remote_address.inspect}"
		
		while data = peer.readpartial(1000*1000)
			puts "Received: #{data.bytesize} bytes"
			sleep 0.001
		end
	rescue EOFError
		# Ignore.
	ensure
		peer.close
	end
ensure
	server_task.stop
end
