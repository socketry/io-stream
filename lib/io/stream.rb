# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2026, by Samuel Williams.

require_relative "stream/version"
require_relative "stream/buffered"
require_relative "stream/duplex"

# @namespace
class IO
	# @namespace
	module Stream
		# Construct a buffered duplex stream from separate input and output endpoints.
		# @parameter input [IO] The readable endpoint.
		# @parameter output [IO] The writable endpoint.
		# @parameter options [Hash] Additional options passed to the buffered stream wrapper.
		# @returns [IO::Stream::Buffered] A buffered stream wrapping a duplex transport.
		def self.Duplex(input, output = input, **options)
			Buffered.wrap(Duplex.new(input, output), **options)
		end
	end
	
	# Convert any IO-like object into a buffered stream.
	# @parameter io [IO] The IO object to wrap.
	# @returns [IO::Stream::Buffered] A buffered stream wrapper.
	def self.Stream(io)
		if io.is_a?(Stream::Buffered)
			io
		else
			Stream::Buffered.wrap(io)
		end
	end
end
