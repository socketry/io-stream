# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'io/stream'

describe IO::Stream do
	it "can wrap an IO object" do
		io = StringIO.new
		
		stream = IO::Stream(io)
		
		expect(stream).to be_a(IO::Stream::Buffered)
	end
	
	it "can wrap an existing stream" do
		io = StringIO.new
		
		stream = IO::Stream(io)
		stream2 = IO::Stream(stream)
		
		expect(stream2).to be_equal(stream)
	end
end