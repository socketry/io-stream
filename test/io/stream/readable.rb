# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Andrew Fader.

require "io/stream/generic"
require "objspace"

# Deliver exact read sizes while honoring sysread's output-buffer contract.
# Socket writes cannot guarantee these boundaries, and this source never blocks.
class ScriptedReadableStream < IO::Stream::Generic
	def initialize(chunks)
		@chunks = chunks.dup
		@destinations = []
		super()
	end
	
	attr :destinations
	
	protected
	
	def sysread(size, buffer)
		return unless chunk = @chunks.shift
		raise "Scripted chunk exceeds requested read size" if chunk.bytesize > size
		
		@destinations << buffer
		buffer.clear
		buffer << chunk
		return buffer
	end
end

describe IO::Stream::Readable do
	# The smallest read_partial that is handed over without a copy:
	threshold = IO::Stream::MINIMUM_READ_SIZE / IO::Stream::HANDOVER_RATIO
	
	with "read buffer ownership" do
		[threshold - 1, threshold, threshold + 1].each do |size|
			with "a #{size}-byte read", unique: size do
				it "copies only below the threshold and preserves returned data across later reads" do
					first = "a".b * size
					second = "b".b * threshold
					third = "c".b * 64
					stream = ScriptedReadableStream.new([first, second, third])
					
					chunk = stream.read_partial
					expect(chunk).to be == first
					expect(chunk.encoding).to be == Encoding::BINARY
					if size < threshold
						expect(chunk).not.to be_equal(stream.destinations.first)
					else
						expect(chunk).to be_equal(stream.destinations.first)
					end
					
					next_chunk = stream.read_partial
					expect(next_chunk).to be == second
					expect(chunk).to be == first
					expect(stream.read_partial).to be == third
					expect(chunk).to be == first
					expect(next_chunk).to be == second
					expect(stream.read_partial).to be_nil
				end
			end
		end
		
		it "reuses the input buffer for small reads without changing retained chunks" do
			chunks = ["a".b * 64, "b".b * 64, "c".b * 64]
			stream = ScriptedReadableStream.new(chunks)
			retained = chunks.map{stream.read_partial}
			
			expect(retained).to be == chunks
			expect(stream.destinations[1]).to be_equal(stream.destinations[0])
			expect(stream.destinations[2]).to be_equal(stream.destinations[0])
			expect(stream.read_partial).to be_nil
		end
		
		it "appends a large read to buffered data without losing either part" do
			first = "a".b * 64
			second = "b".b * threshold
			stream = ScriptedReadableStream.new([first, second, "end".b])
			
			chunk = stream.read(first.bytesize + second.bytesize)
			expect(chunk).to be == first + second
			expect(stream.read_partial).to be == "end"
			expect(chunk).to be == first + second
			expect(stream.read_partial).to be_nil
		end
		
		it "preserves slices of a handed-over buffer across subsequent reads" do
			first = "a".b * threshold
			second = "b".b * threshold
			stream = ScriptedReadableStream.new([first, second])
			
			prefix = stream.read_partial(64)
			remainder = stream.read_partial
			expect(prefix).to be == first.byteslice(0, 64)
			expect(remainder).to be == first.byteslice(64..)
			expect(stream.read_partial).to be == second
			expect(prefix + remainder).to be == first
			expect(stream.read_partial).to be_nil
		end
		
		it "copies a small read into a string of exactly its size" do
			# Just over a power of two, where appending to an empty string would almost double the capacity:
			chunk = "a".b * (threshold / 2 + 1)
			stream = ScriptedReadableStream.new([chunk])
			
			copy = stream.read_partial
			expect(copy).to be == chunk
			expect(copy.encoding).to be == Encoding::BINARY
			expect(ObjectSpace.memsize_of(copy)).to be < chunk.bytesize + 1024
		end
		
		it "compares against the largest earlier read, not the current one" do
			large = IO::Stream::MINIMUM_READ_SIZE * 4
			stream = ScriptedReadableStream.new(["a".b * 64, "b".b * threshold])
			
			# A large read, as `read(large)` would make, grows the reused input buffer but returns only a small chunk:
			stream.send(:fill_read_buffer, large)
			expect(stream.read_partial).to be == "a".b * 64
			
			# The input buffer is now much larger than this read, so it is copied too:
			chunk = stream.read_partial
			expect(chunk).to be == "b".b * threshold
			expect(chunk).not.to be_equal(stream.destinations.last)
		end
	end
end
