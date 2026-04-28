# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module IO::Stream
	# A low-level duplex IO adapter that composes distinct readable and writable endpoints.
	class Duplex
		def initialize(input, output = input)
			@input = input
			@output = output
		end
		
		attr :input
		attr :output
		
		def to_io
			@input || @output
		end
		
		def timeout
			[@input.timeout, @output.timeout].compact.max
		end
		
		def timeout=(duration)
			@input.timeout = duration
			@output.timeout = duration
		end
		
		def closed?
			@input.closed? && @output.closed?
		end
		
		def close_read
			return if @input.closed?
			
			if @input.respond_to?(:close_read)
				@input.close_read
			else
				@input.close
			end
		end
		
		def close_write
			return if @output.closed?
			
			if @output.respond_to?(:close_write)
				@output.close_write
			else
				@output.close
			end
		end
		
		def readable?
			@input.readable?
		end
		
		def close
			@output.close unless @output.closed?
			@input.close unless @input.closed?
		end
		
		def write(buffer)
			@output.write(buffer)
		end
		
		def read_nonblock(size, buffer, exception: false)
			@input.read_nonblock(size, buffer, exception: exception)
		end
		
		def wait_readable(duration = @timeout)
			@input.wait_readable(duration)
		end
		
		def wait_writable(duration = @timeout)
			@output.wait_writable(duration)
		end
	end
end
