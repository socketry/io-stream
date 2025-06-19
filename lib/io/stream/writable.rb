# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require_relative "readable"

module IO::Stream
	# The minimum write size before flushing. Defaults to 64KB.
	MINIMUM_WRITE_SIZE = ENV.fetch("IO_STREAM_MINIMUM_WRITE_SIZE", BLOCK_SIZE).to_i
	
	# A module providing writable stream functionality.
	module Writable
		def initialize(minimum_write_size: MINIMUM_WRITE_SIZE, **, &block)
			@writing = ::Thread::Mutex.new
			@write_buffer = StringBuffer.new
			@minimum_write_size = minimum_write_size
			
			super(**, &block) if defined?(super)
		end
		
		attr_accessor :minimum_write_size
		
		private def drain(buffer)
			begin
				syswrite(buffer)
			ensure
				# If the write operation fails, we still need to clear this buffer, and the data is essentially lost.
				buffer.clear
			end
		end
		
		# Flushes buffered data to the stream.
		def flush
			return if @write_buffer.empty?
			
			@writing.synchronize do
				self.drain(@write_buffer)
			end
		end
		
		# Writes `string` to the buffer. When the buffer is full or #sync is true the
		# buffer is flushed to the underlying `io`.
		# @parameter string [String] the string to write to the buffer.
		# @returns [Integer] the number of bytes appended to the buffer.
		def write(string, flush: false)
			@writing.synchronize do
				@write_buffer << string
				
				flush |= (@write_buffer.bytesize >= @minimum_write_size)
				
				if flush
					self.drain(@write_buffer)
				end
			end
			
			return string.bytesize
		end
		
		# Writes `string` to the stream and returns self.
		def <<(string)
			write(string)
			
			return self
		end
		
		def puts(*arguments, separator: $/)
			return if arguments.empty?
			
			@writing.synchronize do
				arguments.each do |argument|
					@write_buffer << argument << separator
				end
				
				self.drain(@write_buffer)
			end
		end
		
		def close_write
			flush
		end
	end
end
