#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/io/stream"

require "async"
require "async/safe"

# Enable concurrent access detection:
Async::Safe.enable!

# Create a simple stream with some data:
input, output = IO.pipe
stream = IO::Stream::Buffered.new(input)
output.write("Hello")

Async do |task|
	task.async(transient: true) do
		data = stream.read(10)
	end
	
	# This should raise ViolationError:
	stream.read(10)
end
