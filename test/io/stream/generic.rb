# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "io/stream/generic"

describe IO::Stream::Generic do
	let(:stream) {subject.new}
	
	with "#closed?" do
		it "should return false by default" do
			expect(stream.closed?).to be_falsey
		end
	end
	
	with "#read" do
		it "should raise NotImplementedError" do
			expect{stream.read(10)}.to raise_exception(NotImplementedError)
		end
	end
	
	with "#peek_partial" do
		it "should default to no immediately available data" do
			expect(stream.peek_partial(1)).to be_nil
			expect(stream).to be(:readable?)
		end
	end
	
	with "#flush" do
		it "should raise NotImplementedError" do
			expect{stream.write("hello"); stream.flush}.to raise_exception(NotImplementedError)
		end
	end
	
	with "#close" do
		it "should raise NotImplementedError" do
			expect{stream.close}.to raise_exception(NotImplementedError)
		end
	end
end
