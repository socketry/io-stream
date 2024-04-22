# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require_relative 'generic'

module IO::Stream
	class Buffered < Generic
		def self.open(path, mode = "r+", **options)
			stream = self.new(::File.open(path, mode), **options)
			
			return stream unless block_given?
			
			begin
				yield stream
			ensure
				stream.close
			end
		end
		
		def self.wrap(io, **options)
			if io.respond_to?(:buffered=)
				io.buffered = false
			end
			
			self.new(io, **options)
		end
		
		def initialize(io, ...)
			super(...)
			
			@io = io
		end
		
		attr :io
		
		def closed?
			@io.closed?
		end
		
		def close_read
			@io.close_read
		end
		
		def close_write
			super
		ensure
			@io.close_write
		end
		
		def readable?
			super && @io.readable?
		end
		
		protected
		
		def sysclose
			@io.close
		end
		
		def syswrite(buffer)
			@io.write(buffer)
		end
		
		# Reads data from the underlying stream as efficiently as possible.
		def sysread(size, buffer)
			# Come on Ruby, why couldn't this just return `nil`? EOF is not exceptional. Every file has one.
			while true
				result = @io.read_nonblock(size, buffer, exception: false)
				
				case result
				when :wait_readable
					@io.wait_readable
				when :wait_writable
					@io.wait_writable
				else
					return result
				end
			end
		end
	end
end
