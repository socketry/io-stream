# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "io/stream"

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
	
	it "can wrap an existing duplex stream" do
		input = StringIO.new
		output = StringIO.new
		
		duplex = IO::Stream::Duplex.new(input, output)
		stream = IO::Stream(duplex)
		
		expect(stream).to be_a(IO::Stream::Buffered)
		expect(stream.io).to be_equal(duplex)
	end
	
	it "provides timeout shims for StringIO-backed duplex streams" do
		duplex = IO::Stream::Duplex.new(StringIO.new, StringIO.new)
		
		expect(duplex.timeout).to be_nil
		expect(duplex.timeout = 0.5).to be == 0.5
		expect(duplex.timeout).to be == 0.5
	end
end
