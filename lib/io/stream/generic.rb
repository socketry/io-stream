# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require_relative "string_buffer"
require_relative "readable"
require_relative "writable"

require_relative "shim/buffered"
require_relative "shim/readable"

require_relative "openssl"

module IO::Stream
	class LimitError < StandardError
	end
	
	class Generic
		include Readable
		include Writable
		
		def initialize(**options)
			super(**options)
		end
		
		def closed?
			false
		end
		
		# Best effort to flush any unwritten data, and then close the underling IO.
		def close
			return if closed?
			
			begin
				flush
			rescue
				# We really can't do anything here unless we want #close to raise exceptions.
			ensure
				self.sysclose
			end
		end
		
		protected
		
		def sysclose
			raise NotImplementedError
		end
		
		def syswrite(buffer)
			raise NotImplementedError
		end
		
		# Reads data from the underlying stream as efficiently as possible.
		def sysread(size, buffer)
			raise NotImplementedError
		end
	end
end
