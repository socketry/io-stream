# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "io/stream/buffered"
require "sus/fixtures/async/reactor_context"

describe "IO.pipe" do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:pipe) {IO.pipe}
	let(:client) {IO::Stream::Buffered.wrap(pipe[0])}
	let(:server) {IO::Stream::Buffered.wrap(pipe[1])}
	
	def after(error = nil)
		pipe.each(&:close)
		super
	end
	
	it "can close while writing" do
		message = "." * 1024 * 128
		
		task = reactor.async do
			while true
				# $stderr.puts "-> write"
				server.write(message)
				# $stderr.puts "<- write"
			end
		end
		
		# Become a segfault:
		sleep 0.001
	end
end
