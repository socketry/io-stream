#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Andrew Fader.

# Run from benchmark/: bundle exec ruby http.rb
# Compare checkouts with the same script and installed protocol-http1 version:
#   ruby -I /path/to/checkout/lib /path/to/benchmark/http.rb
# Each sample uses one HTTP/1.1 keep-alive connection, with sequential GETs.
# Setup and 10 warm-up requests are excluded. GC stays enabled. Reports best of
# five samples; server thread and client share a process. This measures HTTP
# parsing and body reads over TCP, without a web framework, TLS, or concurrency.
# Both IPv4 and IPv6 loopback run identical fixed-length and chunked responses.

require "io/stream"
require "protocol/http1/connection"
require "socket"
require "timeout"

module HTTPBenchmark
	def self.sample(host, size, chunked, count)
		payload = ("x".b * size).freeze
		if chunked
			chunks = (0...size).step(16 * 1024).map do |offset|
				chunk = payload.byteslice(offset, 16 * 1024)
				"#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n"
			end
			response = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n#{chunks.join}0\r\n\r\n"
		else
			response = "HTTP/1.1 200 OK\r\nContent-Length: #{size}\r\n\r\n#{payload}"
		end
		response.freeze
		
		listener = TCPServer.new(host, 0)
		socket = TCPSocket.new(host, listener.local_address.ip_port)
		peer = listener.accept
		listener.close
		[socket, peer].each{|io| io.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)}
		connection = Protocol::HTTP1::Connection.new(IO::Stream::Buffered.wrap(socket))
		worker = Thread.new do
			(count + 10).times do
				raise "Unexpected request" unless peer.gets("\r\n") == "GET / HTTP/1.1\r\n"
				loop do
					line = peer.gets("\r\n") or raise EOFError, "Incomplete request headers"
					break if line == "\r\n"
				end
				peer.write(response)
			end
		ensure
			peer.close
		end
		
		request = lambda do |validate|
			connection.write_request("localhost", "GET", "/", "HTTP/1.1", [])
			connection.write_body("HTTP/1.1", nil)
			version, status, _, _, body = connection.read_response("GET")
			raise "Unexpected response" unless version == "HTTP/1.1" && status == 200 && body
			received = 0
			while chunk = body.read
				received += chunk.bytesize
				raise "Corrupt response" if validate && chunk != "x" * chunk.bytesize
			end
			body.close
			raise "Wrong body size: #{received}" unless received == size
		end
		
		10.times{request.call(true)}
		GC.start
		start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		count.times{request.call(false)}
		elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
		worker.value
		elapsed
	ensure
		connection&.close
		socket&.close unless socket&.closed?
		listener&.close unless listener&.closed?
		worker&.kill if worker&.alive?
		worker&.join
		peer&.close unless peer&.closed?
	end
	
	def self.run
		samples = Integer(ENV.fetch("SAMPLES", "5"))
		raise "SAMPLES must be positive" unless samples.positive?
		$stdout.sync = true
		puts "Ruby #{RUBY_VERSION}; io-stream #{IO::Stream::VERSION} (#{$LOADED_FEATURES.find{|path| path.end_with?("/io/stream.rb")}})"
		puts "protocol-http1 #{Gem.loaded_specs.fetch("protocol-http1").version}; best of #{samples}; HTTP/1.1 keep-alive"
		{"IPv4" => "127.0.0.1", "IPv6" => "::1"}.each do |family, host|
			[64, 16 * 1024, 1024 * 1024].each do |size|
				count = Integer(ENV.fetch("REQUESTS", size < 1024 * 1024 ? "2000" : "64"))
				raise "REQUESTS must be positive" unless count.positive?
				[false, true].each do |chunked|
					times = samples.times.map do
						Timeout.timeout(60){sample(host, size, chunked, count)}
					end
					best = times.min
					printf "%s %-7s %7d B: %9.0f requests/s, %8.1f MiB/s (%d requests/sample)\n",
						family, chunked ? "chunked" : "fixed", size, count / best, count * size / best / 1048576.0, count
				end
			end
		end
	end
end

HTTPBenchmark.run if $PROGRAM_NAME == __FILE__
