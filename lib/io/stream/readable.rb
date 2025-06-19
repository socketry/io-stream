# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require_relative "string_buffer"

module IO::Stream
	# The default block size for IO buffers. Defaults to 256KB (optimized for modern SSDs and networks).
	BLOCK_SIZE = ENV.fetch("IO_STREAM_BLOCK_SIZE", 1024*256).to_i

	# The minimum read size for efficient I/O operations. Defaults to the same as BLOCK_SIZE.
	MINIMUM_READ_SIZE = ENV.fetch("IO_STREAM_MINIMUM_READ_SIZE", BLOCK_SIZE).to_i

	# The maximum read size for a single read operation. This limit exists because:
	# 1. System calls like read() cannot handle requests larger than SSIZE_MAX
	# 2. Very large reads can cause memory pressure and poor interactive performance  
	# 3. Most socket buffers and pipe capacities are much smaller anyway
	# On 64-bit systems SSIZE_MAX is ~8.8 million MB, on 32-bit it's ~2GB.
	# Our default of 16MB provides a good balance of throughput and responsiveness, and is page aligned.
	# It is also a multiple of the minimum read size, so that we can read in chunks without exceeding the maximum.
	MAXIMUM_READ_SIZE = ENV.fetch("IO_STREAM_MAXIMUM_READ_SIZE", MINIMUM_READ_SIZE * 64).to_i
	
	# A module providing readable stream functionality.
	module Readable
		def initialize(minimum_read_size: MINIMUM_READ_SIZE, maximum_read_size: MAXIMUM_READ_SIZE, block_size: nil, **, &block)
			@done = false
			@read_buffer = StringBuffer.new
			# Used as destination buffer for underlying reads.
			@input_buffer = StringBuffer.new
			
			# Support legacy block_size parameter for backwards compatibility
			@minimum_read_size = block_size || minimum_read_size
			@maximum_read_size = maximum_read_size
			
			super(**, &block) if defined?(super)
		end
		
		attr_accessor :minimum_read_size
		
		# Legacy accessor for backwards compatibility
		def block_size
			@minimum_read_size
		end
		
		def block_size=(value)
			@minimum_read_size = value
		end
		
		def read(size = nil)
			return String.new(encoding: Encoding::BINARY) if size == 0
			
			if size
				until @done or @read_buffer.bytesize >= size
					# Compute the amount of data we need to read from the underlying stream:
					read_size = size - @read_buffer.bytesize
					
					# Don't read less than @minimum_read_size to avoid lots of small reads:
					fill_read_buffer(read_size > @minimum_read_size ? read_size : @minimum_read_size)
				end
			else
				until @done
					fill_read_buffer
				end
			end
			
			return consume_read_buffer(size)
		end
		
		# Read at most `size` bytes from the stream. Will avoid reading from the underlying stream if possible.
		def read_partial(size = nil)
			return String.new(encoding: Encoding::BINARY) if size == 0
		
			if !@done and @read_buffer.empty?
				fill_read_buffer
			end
			
			return consume_read_buffer(size)
		end
		
		def read_exactly(size, exception: EOFError)
			if buffer = read(size)
				if buffer.bytesize != size
					raise exception, "Could not read enough data!"
				end
				
				return buffer
			end
			
			raise exception, "Encountered done while reading data!"
		end
		
		# This is a compatibility shim for existing code that uses `readpartial`.
		def readpartial(size = nil)
			read_partial(size) or raise EOFError, "Encountered done while reading data!"
		end
		
		private def index_of(pattern, offset, limit)
			# We don't want to split on the pattern, so we subtract the size of the pattern.
			split_offset = pattern.bytesize - 1

			until index = @read_buffer.index(pattern, offset)
				offset = @read_buffer.bytesize - split_offset
				
				offset = 0 if offset < 0
				
				return nil if limit and offset >= limit
				return nil unless fill_read_buffer
			end
			
			return index
		end
		
		# Efficiently read data from the stream until encountering pattern.
		# @parameter pattern [String] The pattern to match.
		# @parameter offset [Integer] The offset to start searching from.
		# @parameter limit [Integer] The maximum number of bytes to read, including the pattern (even if chomped).
		# @returns [String | Nil] The contents of the stream up until the pattern, which is consumed but not returned.
		def read_until(pattern, offset = 0, limit: nil, chomp: true)
			if index = index_of(pattern, offset, limit)
				return nil if limit and index >= limit
				
				@read_buffer.freeze
				matched = @read_buffer.byteslice(0, index+(chomp ? 0 : pattern.bytesize))
				@read_buffer = @read_buffer.byteslice(index+pattern.bytesize, @read_buffer.bytesize)
				
				return matched
			end
		end
		
		def peek(size = nil)
			if size
				until @done or @read_buffer.bytesize >= size
					# Compute the amount of data we need to read from the underlying stream:
					read_size = size - @read_buffer.bytesize
					
					# Don't read less than @minimum_read_size to avoid lots of small reads:
					fill_read_buffer(read_size > @minimum_read_size ? read_size : @minimum_read_size)
				end
				return @read_buffer[..([size, @read_buffer.size].min - 1)]
			end
			until (block_given? && yield(@read_buffer)) or @done
				fill_read_buffer
			end
			return @read_buffer
		end
		
		def gets(separator = $/, limit = nil, chomp: false)
			# Compatibility with IO#gets:
			if separator.is_a?(Integer)
				limit = separator
				separator = $/
			end
			
			# We don't want to split in the middle of the separator, so we subtract the size of the separator from the start of the search:
			split_offset = separator.bytesize - 1
			
			offset = 0
			
			until index = @read_buffer.index(separator, offset)
				offset = @read_buffer.bytesize - split_offset
				offset = 0 if offset < 0
				
				# If a limit was given, and the offset is beyond the limit, we should return up to the limit:
				if limit and offset >= limit
					# As we didn't find the separator, there is nothing to chomp either.
					return consume_read_buffer(limit)
				end
				
				# If we can't read any more data, we should return what we have:
				return consume_read_buffer unless fill_read_buffer
			end
			
			# If the index of the separator was beyond the limit:
			if limit and index >= limit
				# Return up to the limit:
				return consume_read_buffer(limit)
			end
			
			# Freeze the read buffer, as this enables us to use byteslice without generating a hidden copy:
			@read_buffer.freeze
			
			line = @read_buffer.byteslice(0, index+(chomp ? 0 : separator.bytesize))
			@read_buffer = @read_buffer.byteslice(index+separator.bytesize, @read_buffer.bytesize)
			
			return line
		end
		
		# Determins if the stream has consumed all available data. May block if the stream is not readable.
		# See {readable?} for a non-blocking alternative.
		#
		# @returns [Boolean] If the stream is at file which means there is no more data to be read.
		def done?
			if !@read_buffer.empty?
				return false
			elsif @done
				return true
			else
				return !self.fill_read_buffer
			end
		end
		
		alias eof? done?
		
		def done!
			@read_buffer.clear
			@done = true
			
			raise EOFError
		end
		
		alias eof! done!
		
		# Whether there is a chance that a read operation will succeed or not.
		# @returns [Boolean] If the stream is readable, i.e. a `read` operation has a chance of success.
		def readable?
			# If we are at the end of the file, we can't read any more data:
			if @done
				return false
			end
			
			# If the read buffer is not empty, we can read more data:
			if !@read_buffer.empty?
				return true
			end
			
			# If the underlying stream is readable, we can read more data:
			return !closed?
		end
		
		def close_read
		end
		
		private
		
		# Fills the buffer from the underlying stream.
		def fill_read_buffer(size = @minimum_read_size)
			# Limit the read size to avoid exceeding SSIZE_MAX and to manage memory usage.
			# Very large reads can also hurt interactive performance by blocking for too long.
			if size > @maximum_read_size
				size = @maximum_read_size
			end
			
			# This effectively ties the input and output stream together.
			flush
			
			if @read_buffer.empty?
				if sysread(size, @read_buffer)
					# Console.info(self, name: "read") {@read_buffer.inspect}
					return true
				end
			else
				if chunk = sysread(size, @input_buffer)
					@read_buffer << chunk
					# Console.info(self, name: "read") {@read_buffer.inspect}
					
					return true
				end
			end
			
			# else for both cases above:
			@done = true
			return false
		end
		
		# Consumes at most `size` bytes from the buffer.
		# @parameter size [Integer|nil] The amount of data to consume. If nil, consume entire buffer.
		def consume_read_buffer(size = nil)
			# If we are at done, and the read buffer is empty, we can't consume anything.
			return nil if @done && @read_buffer.empty?
			
			result = nil
			
			if size.nil? or size >= @read_buffer.bytesize
				# Consume the entire read buffer:
				result = @read_buffer
				@read_buffer = StringBuffer.new
			else
				# This approach uses more memory.
				# result = @read_buffer.slice!(0, size)
				
				# We know that we are not going to reuse the original buffer.
				# But byteslice will generate a hidden copy. So let's freeze it first:
				@read_buffer.freeze
				
				result = @read_buffer.byteslice(0, size)
				@read_buffer = @read_buffer.byteslice(size, @read_buffer.bytesize)
			end
			
			return result
		end
	end
end
