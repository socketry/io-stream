# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "io/stream/buffered"
require "sus/fixtures/async/reactor_context"

describe "IO.pipe" do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:pipe) {IO.pipe}
	let(:client) {IO::Stream::Buffered.wrap(pipe[0])}
	let(:server) {IO::Stream::Buffered.wrap(pipe[1])}
	
	after do
		pipe.each(&:close)
	end
	
	it "can close while writing" do
		message = "." * 1024 * 128
		
		task = reactor.async do
			loop do
				# $stderr.puts "-> write"
				server.write(message)
				# $stderr.puts "<- write"
			rescue IOError => error
				expect(error.message).to be =~ /closed/
				break
			end
		end
		
		# Become a segfault:
		sleep 0.001
	end
end
