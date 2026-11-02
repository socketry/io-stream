#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Andrew Fader.

require "sus/fixtures/benchmark"
require "io/stream"
require "openssl"
require "objspace"
require "socket"

# Run from this directory: `bundle exec sus read.rb`.
#
# Each of 10 samples streams 16 MiB from a writer thread over loopback, plain TCP or
# TLS, and reads it back. An untimed pass then measures the memory held by the
# chunks handed out (average per chunk, ratio to bytes read, and largest chunk).
describe IO::Stream::Buffered do
	include Sus::Fixtures::Benchmark
	
	TOTAL = 16 * 1024 * 1024
	
	def self.certificate
		@certificate ||= begin
			key = OpenSSL::PKey::EC.generate("prime256v1")
			certificate = OpenSSL::X509::Certificate.new
			certificate.version = 2
			certificate.serial = 1
			certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/CN=localhost")
			certificate.public_key = key
			certificate.not_before = Time.now - 60
			certificate.not_after = Time.now + 3600
			certificate.sign(key, OpenSSL::Digest.new("SHA256"))
			[certificate, key]
		end
	end
	
	def connect(tls:, write_size:)
		listener = TCPServer.new("localhost", 0)
		client = TCPSocket.new("localhost", listener.local_address.ip_port)
		server = listener.accept
		listener.close
		
		if tls
			certificate, key = self.class.certificate
			server_context = OpenSSL::SSL::SSLContext.new
			server_context.cert = certificate
			server_context.key = key
			client_context = OpenSSL::SSL::SSLContext.new
			client_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
			
			server = OpenSSL::SSL::SSLSocket.new(server, server_context)
			client = OpenSSL::SSL::SSLSocket.new(client, client_context)
			server.sync_close = client.sync_close = true
			accept = Thread.new{server.accept}
			client.connect
			accept.join
		end
		
		line = ("x" * (write_size - 1) + "\n").b.freeze
		writer = Thread.new do
			(TOTAL / write_size).times{server.write(line)}
			server.close
		end
		
		return IO::Stream::Buffered.wrap(client), writer
	end
	
	def stream(tls:, write_size:, &block)
		stream, writer = connect(tls: tls, write_size: write_size)
		block.call(stream)
	ensure
		writer&.join
		stream&.close
	end
	
	READS = {
		"read_partial" => ->(stream){stream.read_partial},
		"read(64 KiB)" => ->(stream){stream.read(64 * 1024)},
		"gets" => ->(stream){stream.gets},
	}
	
	{"TCP" => false, "TLS" => true}.each do |transport, tls|
		with transport, unique: transport do
			[512, 16 * 1024, 1024 * 1024].each do |write_size|
				READS.each do |name, read|
					measure "#{name} of #{write_size}-byte writes", unique: "#{name}-#{write_size}" do |repeats|
						repeats.exactly(10).times do
							stream(tls: tls, write_size: write_size) do |stream|
								while read.(stream)
								end
							end
						end
						
						# One more pass, untimed, to measure the memory held by the chunks handed out:
						reads = bytes = held = largest = 0
						stream(tls: tls, write_size: write_size) do |stream|
							while chunk = read.(stream)
								reads += 1
								bytes += chunk.bytesize
								memsize = ObjectSpace.memsize_of(chunk)
								held += memsize
								largest = memsize if memsize > largest
							end
							inform format("%d reads, %d bytes/chunk (%0.2fx data), largest chunk holds %d bytes", reads, held / reads, held.to_f / bytes, largest)
						end
					end
				end
			end
		end
	end
end
