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
		end
	end
end
