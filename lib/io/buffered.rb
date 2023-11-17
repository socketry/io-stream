
require 'socket'
require 'stringio'

unless IO.method_defined?(:buffered?)
	class IO
		def buffered?
			return !self.sync
		end
		
		def buffered=(value)
			self.sync = !value
		end
	end
end

unless BasicSocket.method_defined?(:buffered?)
	class BasicSocket
		# Is it likely that the socket is still connected?
		# May return false positive, but won't return false negative.
		def buffered?
			return false unless super
			
			case self.local_address.protocol
			when IPPROTO_TCP
				return !self.getsockopt(IPPROTO_TCP, TCP_NODELAY).bool
			else
				return true
			end
		end
		
		def buffered=(value)
			super
			
			case self.local_address.socktype
			when SOCK_STREAM
				# When buffered is set to true, TCP_NODELAY shold be disabled.
				self.setsockopt(IPPROTO_TCP, TCP_NODELAY, value ? 0 : 1)
			end
		rescue Errno::EINVAL
			# On Darwin, sometimes occurs when the connection is not yet fully formed. Empirically, TCP_NODELAY is enabled despite this result.
		rescue Errno::EOPNOTSUPP
			# Some platforms may simply not support the operation.
		end
	end
end

unless StringIO.method_defined?(:buffered?)
	class StringIO
		def buffered?
			return !self.sync
		end
		
		def buffered=(value)
			self.sync = !value
		end
	end
end
