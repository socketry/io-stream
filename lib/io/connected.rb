
require 'socket'

unless IO.method_defined?(:connected?)
	class IO
		def connected?
			return false if self.closed?
		end
	end
end

unless BasicSocket.method_defined?(:connected?)
	class BasicSocket
		# Is it likely that the socket is still connected?
		# May return false positive, but won't return false negative.
		def connected?
			return false unless super
			
			# If we can wait for the socket to become readable, we know that the socket may still be open.
			result = to_io.recv_nonblock(1, MSG_PEEK, exception: false)
			
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
