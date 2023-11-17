
module IO::Stream
	# The default block size for IO buffers. Defaults to 64KB (typical pipe buffer size).
	BLOCK_SIZE = ENV.fetch('IO_STREAM_BLOCK_SIZE', 1024*64).to_i
	
	# The maximum read size when appending to IO buffers. Defaults to 8MB.
	MAXIMUM_READ_SIZE = ENV.fetch('IO_STREAM_MAXIMUM_READ_SIZE', BLOCK_SIZE * 128).to_i
	
	def self.connected?(io)
		return false if io.closed?
		
		io = io.to_io
		
		if io.respond_to?(:recv_nonblock)
			# If we can wait for the socket to become readable, we know that the socket may still be open.
			result = io.to_io.recv_nonblock(1, MSG_PEEK, exception: false)

			# No data was available - newer Ruby can return nil instead of empty string:
			return false if result.nil?
			
			# Either there was some data available, or we can wait to see if there is data avaialble.
			return !result.empty? || result == :wait_readable
			
		rescue Errno::ECONNRESET
			# This might be thrown by recv_nonblock.
			return false
		end
	end
end
