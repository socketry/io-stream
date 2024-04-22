require 'openssl'

module OpenSSL
	module SSL
		class SSLSocket
			unless method_defined?(:close_read)
				def close_read
					# Ignored.
				end
			end
			
			unless method_defined?(:close_write)
				def close_write
					self.stop
				end
			end
			
			unless method_defined?(:wait_readable)
				def wait_readable(...)
					to_io.wait_readable(...)
				end
			end
			
			unless method_defined?(:wait_writable)
				def wait_writable(...)
					to_io.wait_writable(...)
				end
			end
		end
	end
end
