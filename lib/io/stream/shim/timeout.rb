# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "stringio"

class StringIO
	unless method_defined?(:timeout)
		def timeout
			@timeout
		end
	end
	
	unless method_defined?(:timeout=)
		def timeout=(duration)
			@timeout = duration
		end
	end
end
