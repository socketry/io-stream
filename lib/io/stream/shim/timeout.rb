# frozen_string_literal: true

class IO
	unless const_defined?(:TimeoutError)
		# Compatibility shim.
		class TimeoutError < IOError
		end
	end
	
	unless method_defined?(:timeout)
		# Compatibility shim.
		attr_accessor :timeout
	end
end
