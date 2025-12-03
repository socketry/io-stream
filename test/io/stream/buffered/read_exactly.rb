# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

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
	
	it "should handle concurrent read_exactly calls from two fibers" do
		server.write("Hello World!")
		server.flush

		# Spawn two fibers that both call read_exactly concurrently
		# This simulates the race condition scenario from activecypher
		# where two async tasks might call read_exactly on the same stream
		# and one might freeze @read_buffer while the other is trying to use it
		fiber1 = reactor.async do |task|
			client.read_exactly(100)
		end
		
		fiber2 = reactor.async do |task|
			client.read_exactly(100)
		end

		binding.irb
		
		# Wait for both fibers to complete
		# This should not raise FrozenError even if buffers are frozen
		result1 = fiber1.wait
		result2 = fiber2.wait
	end
end
