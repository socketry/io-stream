# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'io/stream/string_buffer'

describe IO::Stream::StringBuffer do
	let(:string_buffer) {subject.new}
	
	it "should be a subclass of String" do
		expect(subject).to be < String
	end
	
	it "should have a binary encoding" do
		expect(string_buffer.encoding).to be == Encoding::BINARY
	end
	
	it "should append unicode strings" do
		string_buffer << "Hello, World!".force_encoding(Encoding::UTF_8)
		
		expect(string_buffer).to be == "Hello, World!"
		expect(string_buffer.encoding).to be == Encoding::BINARY
	end
	
	it "should append binary strings" do
		string_buffer << "Hello, World!".force_encoding(Encoding::BINARY)
		
		expect(string_buffer).to be == "Hello, World!"
		expect(string_buffer.encoding).to be == Encoding::BINARY
	end
end
