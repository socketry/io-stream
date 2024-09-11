#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "bundler/inline"

gemfile do
	source "https://rubygems.org"
	gem "localhost"
end

require "socket"
require "openssl"
require "localhost"

def read_after_close(io)
	io.close
	io.read
end

begin
	client, server = Socket.pair(:UNIX, :STREAM)
	read_after_close(client)
rescue => error
	$stderr.puts error.full_message
end

begin
	authority = Localhost::Authority.fetch
		
	client, server = Socket.pair(:UNIX, :STREAM)
		
	ssl_server = OpenSSL::SSL::SSLSocket.new(server, authority.server_context)
	ssl_server.sync_close = true
		
	ssl_client = OpenSSL::SSL::SSLSocket.new(client, authority.client_context)
	ssl_client.sync_close = true # If this is not set, `io.read` above will hang which is also a bit odd.
		
	Thread.new{ssl_server.accept}
		
	ssl_client.connect
		
	read_after_close(ssl_client)
rescue => error
	$stderr.puts error.full_message
end
