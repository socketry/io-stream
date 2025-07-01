# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "io/stream/buffered"
require "tempfile"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/openssl/verified_certificate_context"
require "sus/fixtures/openssl/valid_certificate_context"

describe IO::Stream::Buffered do
	# This constant is part of the public interface, but was renamed to `Async::IO::BLOCK_SIZE`.
	with "BLOCK_SIZE" do
		it "should exist and be reasonable" do
			expect(IO::Stream::BLOCK_SIZE).to be_within(1024...1024*1024)
		end
	end
	
	with "MAXIMUM_READ_SIZE" do
		it "should exist and be reasonable" do
			expect(IO::Stream::MAXIMUM_READ_SIZE).to be_within(1024*64..1024*64*512)
		end
	end
	
	with ".open" do
		let(:tempfile) {Tempfile.new("io_stream_buffered_test")}
		let(:test_file_path) {tempfile.path}
		
		after do
			tempfile.close
			tempfile.unlink
		end
		
		it "can open a file and return a buffered stream" do
			stream = IO::Stream::Buffered.open(test_file_path, "w+")
			
			expect(stream).to be_a(IO::Stream::Buffered)
			expect(stream.io).to be_a(File)
			
			stream.write("Hello, World!")
			stream.flush
			stream.close
			
			content = File.read(test_file_path)
			expect(content).to be == "Hello, World!"
		end
		
		it "can open a file with a block and auto-close" do
			result = nil
			stream_reference = nil
			
			# Create a separate tempfile for this test to avoid conflicts
			block_tempfile = Tempfile.new("io_stream_buffered_block_test")
			block_file_path = block_tempfile.path
			block_tempfile.close
			
			begin
				result = IO::Stream::Buffered.open(block_file_path, "w+") do |stream|
					stream_reference = stream
					
					expect(stream).to be_a(IO::Stream::Buffered)
					expect(stream.io).to be_a(File)
					
					stream.write("Block test data")
					stream.flush
					
					:block_result
				end
				
				# The block's return value should be returned
				expect(result).to be == :block_result
				
				# The stream should be automatically closed
				expect(stream_reference).to be(:closed?)
				
				# The file should contain the written data
				content = File.read(block_file_path)
				expect(content).to be == "Block test data"
			ensure
				File.unlink(block_file_path) if File.exist?(block_file_path)
			end
			expect(content).to be == "Block test data"
		end
		
		it "ensures stream is closed even when block raises an exception" do
			stream_reference = nil
			
			expect do
				IO::Stream::Buffered.open(test_file_path, "w+") do |stream|
					stream_reference = stream
					
					stream.write("Exception test")
					stream.flush
					
					raise StandardError, "Test exception"
				end
			end.to raise_exception(StandardError, message: be == "Test exception")
			
			# The stream should be closed despite the exception
			expect(stream_reference).to be(:closed?)
			
			# The file should still contain the written data
			content = File.read(test_file_path)
			expect(content).to be == "Exception test"
		end
	end
end

AUnidirectionalStream = Sus::Shared("a unidirectional stream") do
	it "should be able to read and write data" do
		server.write "Hello, World!"
		server.flush
		
		expect(client.read(13)).to be == "Hello, World!"
	end
	
	with "#buffered?" do
		it "should not be buffered" do
			expect(client.io).not.to be(:buffered?)
		end
	end
	
	with "#read" do
		it "can read zero length" do
			data = client.read(0)
			
			expect(data).to be == ""
			expect(data.encoding).to be == Encoding::BINARY
		end
		
		it "reads everything" do
			server.write "Hello World"
			server.close
			
			expect(client).to receive(:sysread).twice
			
			expect(client.read).to be == "Hello World"
			expect(client).to be(:eof?)
		end

		it "reads only the amount requested" do
			server.write "Hello World"
			server.close
			
			expect(client).to receive(:sysread).once
			
			expect(client.read_partial(4)).to be == "Hell"
			expect(client).not.to be(:eof?)
			
			expect(client.read_partial(20)).to be == "o World"
		end
		
		it "times out when reading" do
			client.io.timeout = 0.001
			
			expect do
				client.read(1)
			end.to raise_exception(::IO::TimeoutError)
		end
		
		with "buffer parameter" do
			it "can read into a provided buffer" do
				server.write "Hello World!"
				server.close
				
				buffer = String.new("existing content")
				result = client.read(5, buffer)
				
				# Should return the same buffer object
				expect(result).to be_equal(buffer)
				# Buffer should contain the read data and have binary encoding
				expect(result).to be == "Hello"
				expect(result.encoding).to be == Encoding::BINARY
			end
			
			it "clears existing buffer content before reading" do
				server.write "Hello World!"
				server.close
				
				buffer = String.new("old data")
				result = client.read(5, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result).to be == "Hello"
			end
			
			it "works with zero-length reads" do
				buffer = String.new("content")
				result = client.read(0, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result).to be == ""
				expect(result.encoding).to be == Encoding::BINARY
			end
			
			it "works when reading entire stream" do
				server.write "Hello World!"
				server.close
				
				buffer = String.new
				result = client.read(nil, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result).to be == "Hello World!"
			end
			
			it "works with partial reads spanning multiple buffer fills" do
				# Write more data than the typical buffer size to force multiple reads
				large_data = "A" * 1000 + "B" * 1000 + "C" * 1000
				server.write large_data
				server.close
				
				buffer = String.new
				result = client.read(2500, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result.bytesize).to be == 2500
				expect(result).to be == large_data[0, 2500]
			end
			
			it "returns nil when stream is done and buffer is empty" do
				server.close
				
				buffer = String.new("content")
				result = client.read(10, buffer)
				
				expect(result).to be_nil
				
				# Buffer should be cleared even when returning nil:
				expect(buffer).to be == ""
			end
		end
	end
	
	with "#peek" do
		it "can peek at the read buffer" do
			server.write "Hello World"
			server.close
			
			expect(client).to receive(:sysread).once
			
			expect(client.peek(4)).to be == "Hell"
			expect(client.peek(4)).to be == "Hell"
			
			expect(client.read_partial).to be == "Hello World"
		end
		
		it "peeks everything" do
			server.write "Hello World"
			server.close
			
			expect(client).to receive(:sysread).twice
			
			expect(client.peek).to be == "Hello World"
			expect(client.read).to be == "Hello World"
			expect(client).to be(:eof?)
		end
		
		it "peeks only the amount requested" do
			server.write "Hello World"
			server.close
			
			expect(client).to receive(:sysread).twice
			
			expect(client.peek(4)).to be == "Hell"
			expect(client.read_partial(4)).to be == "Hell"
			expect(client).not.to be(:eof?)
			
			expect(client.peek(20)).to be == "o World"
			expect(client.read_partial(20)).to be == "o World"
			expect(client).to be(:eof?)
		end

		it "peeks everything when requested bytes is too large" do
			server.write "Hello World"
			server.close
			
			expect(client).to receive(:sysread).twice
			
			expect(client.peek(400)).to be == "Hello World"
			expect(client.read_partial(400)).to be == "Hello World"
			expect(client).to be(:eof?)
		end
	end
	
	with "#read_exactly" do
		it "can read several bytes" do
			server.write "Hello World"
			server.close
			
			expect(client.read_exactly(4)).to be == "Hell"
		end
		
		it "can raise exception if io is eof" do
			server.close
			
			expect do
				client.read_exactly(4)
			end.to raise_exception(EOFError)
		end
		
		with "buffer parameter" do
			it "can read exactly into a provided buffer" do
				server.write "Hello World!"
				server.close
				
				buffer = String.new("existing content")
				result = client.read_exactly(4, buffer)
				
				# Should return the same buffer object
				expect(result).to be_equal(buffer)
				# Buffer should contain exactly the requested data
				expect(buffer).to be == "Hell"
				# Should have binary encoding
				expect(buffer.encoding).to be == Encoding::BINARY
			end
			
			it "clears existing buffer content before reading" do
				server.write "Hello World!"
				server.close
				
				buffer = String.new("old data")
				client.read_exactly(4, buffer)
				
				expect(buffer).to be == "Hell"
			end
			
			it "raises exception when not enough data available" do
				server.write "Hi"  # Only 2 bytes
				server.close
				
				buffer = String.new("content")
				
				expect do
					client.read_exactly(4, buffer)
				end.to raise_exception(EOFError, message: be =~ /Could not read enough data/)
				
				# Buffer should still contain the partial data that was read
				expect(buffer).to be == "Hi"
			end
			
			it "raises exception when stream is already at EOF" do
				server.close
				
				buffer = String.new("content")
				
				expect do
					client.read_exactly(4, buffer)
				end.to raise_exception(EOFError, message: be =~ /Encountered done while reading data/)
				
				# Buffer should be cleared even when exception is raised
				expect(buffer).to be == ""
			end
			
			it "works with zero-length reads" do
				buffer = String.new("content")
				result = client.read_exactly(0, buffer)
				
				expect(result).to be_equal(buffer)
				expect(buffer).to be == ""
				expect(buffer.encoding).to be == Encoding::BINARY
			end
			
			it "works with custom exception class" do
				server.write "Hi"  # Only 2 bytes
				server.close
				
				buffer = String.new("content")
				
				expect do
					client.read_exactly(4, buffer, exception: StandardError)
				end.to raise_exception(StandardError, message: be =~ /Could not read enough data/)
				
				expect(buffer).to be == "Hi"
			end
			
			it "works when exactly the right amount of data is available" do
				server.write "Hello"
				server.close
				
				buffer = String.new
				result = client.read_exactly(5, buffer)
				
				expect(result).to be_equal(buffer)
				expect(buffer).to be == "Hello"
				expect(buffer.bytesize).to be == 5
			end
			
			it "works with mix of buffer and non-buffer calls" do
				server.write "Hello World!"
				server.close
				
				# First call without buffer
				data1 = client.read_exactly(5)
				expect(data1).to be == "Hello"
				
				# Second call with buffer
				buffer = String.new("existing")
				result = client.read_exactly(1, buffer)
				expect(result).to be_equal(buffer)
				expect(buffer).to be == " "
				
				# Third call without buffer again
				data3 = client.read_exactly(6)
				expect(data3).to be == "World!"
			end
			
			it "reads across multiple buffer fills" do
				# Write more data than typical buffer to force multiple reads
				large_data = "A" * 1000 + "B" * 1000 + "C" * 1000
				server.write large_data
				server.close
				
				buffer = String.new
				result = client.read_exactly(2500, buffer)
				
				expect(result).to be_equal(buffer)
				expect(buffer.bytesize).to be == 2500
				expect(buffer).to be == large_data[0, 2500]
			end
		end
	end
	
	with "#read_until" do
		it "can read a line" do
			server.write("hello\nworld\n")
			server.close
			
			expect(client.read_until("\n")).to be == "hello"
			expect(client.read_until("\n")).to be == "world"
			expect(client.read_until("\n")).to be_nil
		end
		
		it "can read with a limit" do
			server.write("hello\nworld\n")
			server.close
			
			expect(client.read_until("\n", limit: 4)).to be_nil
			expect(client.read_until("\n", limit: 5)).to be_nil
			expect(client.read_until("\n", limit: 6)).to be == "hello"
			expect(client.read_until("\n", limit: nil)).to be == "world"
		end
		
		with "1-byte block size" do
			it "can read a line with a multi-byte pattern" do
				server.write("hello\nworld\n")
				server.close
				
				client.block_size = 1
				
				expect(client.read_until("\n")).to be == "hello"
				expect(client.read_until("\n")).to be == "world"
				expect(client.read_until("\n")).to be_nil
			end
		end
	end
	
	with "#gets" do
		it "can read a line" do
			server.write("hello\nworld\nremainder")
			server.close
			
			expect(client.gets).to be == "hello\n"
			expect(client.gets).to be == "world\n"
			expect(client.gets).to be == "remainder"
			expect(client.gets).to be_nil
		end
		
		it "can read with a limit" do
			server.write("hello\nworld\nremainder")
			server.close
			
			expect(client.gets(4)).to be == "hell"
			expect(client.gets(5)).to be == "o\n"
			expect(client.gets(6)).to be == "world\n"
			expect(client.gets).to be == "remainder"
		end
	end
	
	with "#read_partial" do
		def before
			super
			
			string = "Hello World!"
			server.write(string * 2)
			server.close
		end
		
		it "should fill the buffer once" do
			expect(client).to receive(:sysread).once
			
			expect(client.read_partial(12)).to be == "Hello World!"
			expect(client.read_partial(12)).to be == "Hello World!"
		end
		
		it "with a normal partial_read" do
			expect(client.read_partial(1).encoding).to be == Encoding::BINARY
		end
		
		it "with a zero-length partial_read" do
			expect(client.read_partial(0).encoding).to be == Encoding::BINARY
		end
		
		with "buffer parameter" do
			it "can read_partial into a provided buffer" do
				buffer = String.new("existing content")
				result = client.read_partial(5, buffer)
				
				# Should return the same buffer object
				expect(result).to be_equal(buffer)
				# Buffer should contain the read data and have binary encoding
				expect(result).to be == "Hello"
				expect(result.encoding).to be == Encoding::BINARY
			end
			
			it "clears existing buffer content before reading" do
				buffer = String.new("old data")
				result = client.read_partial(5, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result).to be == "Hello"
			end
			
			it "works with zero-length partial reads" do
				buffer = String.new("content")
				result = client.read_partial(0, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result).to be == ""
				expect(result.encoding).to be == Encoding::BINARY
			end
			
			it "works when reading all available data" do
				buffer = String.new
				result = client.read_partial(nil, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result).to be == "Hello World!Hello World!"
			end
			
			it "works with multiple partial reads using same buffer" do
				buffer = String.new
				
				# First partial read
				result1 = client.read_partial(6, buffer)
				expect(result1).to be_equal(buffer)
				expect(result1).to be == "Hello "
				
				# Second partial read reuses the same buffer
				result2 = client.read_partial(6, buffer)
				expect(result2).to be_equal(buffer)
				expect(result2).to be == "World!"
			end
			
			it "returns empty string when maxlen is 0 even at EOF" do
				# Read all data first
				client.read_partial(nil)
				
				buffer = String.new("content")
				result = client.read_partial(0, buffer)
				
				expect(result).to be_equal(buffer)
				expect(result).to be == ""
				expect(result.encoding).to be == Encoding::BINARY
			end
			
			it "works with mix of buffer and non-buffer calls" do
				# First call without buffer
				data1 = client.read_partial(6)
				expect(data1).to be == "Hello "
				
				# Second call with buffer
				buffer = String.new("existing")
				result = client.read_partial(6, buffer)
				expect(result).to be_equal(buffer)
				expect(result).to be == "World!"
				
				# Third call without buffer again
				data3 = client.read_partial(6)
				expect(data3).to be == "Hello "
			end
		end
	end
	
	with "#write" do
		it "should read one line" do
			expect(server).to receive(:syswrite)
			
			server.puts "Hello World"
			server.flush
			
			expect(client.gets).to be == "Hello World\n"
		end
		
		it "times out when writing" do
			server.io.timeout = 0.001
			
			expect do
				while true
					server.write("Hello World")
				end
			end.to raise_exception(::IO::TimeoutError)
		end
	end
	
	with "#<<" do
		it "should append string and return self for method chaining" do
			result = server << "Hello"
			expect(result).to be_equal(server)
			
			server << " " << "World!"
			server.flush
			
			expect(client.read(12)).to be == "Hello World!"
		end
		
		it "should write data without explicit flush" do
			server.minimum_write_size = 5
			
			expect(server).to receive(:syswrite).once
			
			server << "Hello"
			
			expect(client.read(5)).to be == "Hello"
		end
		
		it "should buffer data when below minimum write size" do
			server.minimum_write_size = 10
			
			expect(server).not.to receive(:syswrite)
			
			server << "Hi"
			# Data should still be in buffer, not flushed
		end
	end
	
	with "#flush" do
		it "should not call write if write buffer is empty" do
			expect(server).not.to receive(:syswrite)
			
			server.flush
		end

		it "should flush underlying data when it exceeds block size" do
			expect(server).to receive(:syswrite).once
			
			server.minimum_write_size = 8
			
			8.times do
				server.write("!")
			end
		end
	end
	
	with "#eof?" do
		it "should return true when there is no data available" do
			server.close
			expect(client.eof?).to be_truthy
		end
		
		it "should return false when there is data available" do
			server.write "Hello, World!"
			server.flush
			
			expect(client.eof?).to be_falsey
		end
	end
	
	with "#eof!" do
		it "should immediately raise EOFError" do
			expect do
				client.eof!
			end.to raise_exception(EOFError)
			
			expect(client).to be(:eof?)
		end
	end
	
	with "#readable?" do
		it "should return true when the stream might be open" do
			expect(client.readable?).to be_truthy
		end
		
		it "should return true when there is data available" do
			server.write "Hello, World!"
			server.flush
			
			expect(client.readable?).to be_truthy
		end
		
		it "should return false when the stream is known to be closed" do
			expect(client.readable?).to be_truthy
			server.close
			
			client.read
			expect(client.readable?).to be_falsey
		end
	end
	
	with "#close_write" do
		it "can close the write side of the stream" do
			server.write("Hello World!")
			
			# We are done writing the request:
			server.close_write
			
			expect(client.read).to be == "Hello World!"
			expect(client.eof?).to be_truthy
		end
	end
	
	with "#close" do
		it "should close the stream" do
			server.close
			expect(client.read).to be_nil
			
			expect(server.closed?).to be_truthy
			expect(client.closed?).to be_falsey
		end
		
		it "server should be idempotent" do
			server.close
			server.close
			
			expect(server.closed?).to be_truthy
			expect(client.closed?).to be_falsey
		end
		
		it "client be idempotent" do
			client.close
			client.close
			
			expect(client.closed?).to be_truthy
			expect(server.closed?).to be_falsey
		end
		
		it "should ignore write failures on close" do
			server.write(".")
			
			# Close the underlying IO for whatever reason:
			server.io.close
			
			# This should not raise an exception:
			server.close
			
			expect(server).to be(:closed?)
		end
		
		it "can't read after closing" do
			client.close
			
			expect do
				client.read
			end.to raise_exception(::IOError)
		end
		
		it "can't write after closing" do
			server.close
			
			expect do
				server.write("Hello World")
				server.flush
			end.to raise_exception(::IOError)
		end
		
		it "can close while reading from a different thread" do
			reader = Thread.new do
				Thread.current.report_on_exception = false
				
				client.read
			end
			
			# Wait for the thread to start reading:
			Thread.pass until reader.backtrace(0, 1).find{|line| line.include?("wait_readable")}
			
			client.close
			
			expect do
				reader.join
			end.to raise_exception(::IOError)
		end
	end
	
	with "#drain_write_buffer" do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:buffer_size) {1024*6}
		
		it "can interleave calls to flush" do
			writers = 2.times.map do |i|
				reactor.async do
					buffer = i.to_s * buffer_size
					128.times do
						server.write(buffer)
						server.flush
					end
				end
			end
			
			reader = reactor.async do
				while data = client.read(buffer_size)
					expect(data).to be == (data[0] * buffer_size)
				end
			end
			
			writers.each(&:wait)
			server.close
			
			reader.wait
		end
		
		it "handles write failures" do
			client.close
			
			task = reactor.async do
				server.write("Hello World")
				server.flush
			rescue Errno::EPIPE => error
				error
			end
			
			expect(task.wait).to be_a(Errno::EPIPE)
			
			write_buffer = server.instance_variable_get(:@write_buffer)
			expect(write_buffer).to be(:empty?)
		end
	end
	
	with "#discard_until" do
		it "can discard data until pattern" do
			server.write("hello\nworld\ntest")
			server.close
			
			# Discard until "\n" - should return chunk ending with the pattern
			chunk = client.discard_until("\n")
			expect(chunk).not.to be_nil
			expect(chunk).to be(:end_with?, "\n")
			# Read the remaining data to verify it starts with "world"
			expect(client.read(5)).to be == "world"
			
			# Discard until "t" - should return chunk ending with the pattern  
			chunk = client.discard_until("t")
			expect(chunk).not.to be_nil
			expect(chunk).to be(:end_with?, "t")
			# Read remaining data
			expect(client.read).to be == "est"
		end
		
		it "returns nil when pattern not found and discards all data" do
			server.write("hello world")
			server.close
			
			expect(client.discard_until("\n")).to be_nil
			# Data should still be available since pattern was not found
			expect(client.read).to be == "hello world"
		end
		
		it "can discard with a limit" do
			server.write("hello\nworld\n")
			server.close
			
			# Use peek to verify initial buffer state
			expect(client.peek).to be == "hello\nworld\n"
			
			# Limit too small to find pattern - discards up to limit
			expect(client.discard_until("\n", limit: 4)).to be_nil
			
			# Use peek to verify that 4 bytes were discarded
			expect(client.peek).to be == "o\nworld\n"
			
			# After discarding 4 bytes, should find pattern in remaining data
			chunk = client.discard_until("\n", limit: 5)
			expect(chunk).not.to be_nil
			expect(chunk).to be(:end_with?, "\n")
			
			# Use peek to verify final buffer state
			expect(client.peek).to be == "world\n"
			expect(client.read).to be == "world\n"
		end
		
		it "handles patterns spanning buffer boundaries" do
			# Use a small block size to force the pattern to span boundaries
			client.block_size = 3
			
			server.write("ab")
			server.flush
			server.write("cdef")
			server.close
			
			# Pattern "cd" spans the boundary between "ab" and "cdef"
			chunk = client.discard_until("cd")
			expect(chunk).not.to be_nil
			expect(chunk).to be(:end_with?, "cd")
			expect(client.read).to be == "ef"
		end
		
		it "handles large patterns efficiently" do
			large_pattern = "X" * 20  # Trigger sliding window logic
			server.write("some data before")
			server.write(large_pattern)
			server.write("some data after")
			server.close
			
			chunk = client.discard_until(large_pattern)
			expect(chunk).not.to be_nil
			expect(chunk).to be(:end_with?, large_pattern)
			expect(client.read).to be == "some data after"
		end
		
		with "1-byte block size" do
			it "can discard data with a multi-byte pattern" do
				server.write("hello\nworld\n")
				server.close
				
				client.block_size = 1
				
				chunk1 = client.discard_until("\n")
				expect(chunk1).not.to be_nil
				expect(chunk1).to be(:end_with?, "\n")
				
				chunk2 = client.discard_until("\n")
				expect(chunk2).not.to be_nil
				expect(chunk2).to be(:end_with?, "\n")
				
				expect(client.discard_until("\n")).to be_nil
			end
		end
	end
end

ABidirectionalStream = Sus::Shared("a bidirectional stream") do
	with "#close_write" do
		it "can close the write side of the stream" do
			server.write("Hello World!")
			server.close_write
			
			expect(client.read).to be == "Hello World!"
			expect(client.eof?).to be_truthy
			
			client.write("Goodbye World!")
			client.close_write
			
			expect(server.read).to be == "Goodbye World!"
			expect(server.eof?).to be_truthy
		end
	end
end

describe "IO.pipe" do
	let(:pipe) {IO.pipe}
	let(:client) {IO::Stream::Buffered.wrap(pipe[0])}
	let(:server) {IO::Stream::Buffered.wrap(pipe[1])}
	
	def after(error = nil)
		pipe.each(&:close)
		super
	end
	
	it_behaves_like AUnidirectionalStream
	
	it "can close the writing end of the stream" do
		server.write("Oh yes!")
		server.close_write
		
		expect do
			client.write("Oh no!")
			client.flush
		end.to raise_exception(IOError, message: be =~ /not opened for writing/)
	end
	
	it "can close the reading end of the stream" do
		client.close_read
		
		expect do
			client.read
		end.to raise_exception(IOError, message: be =~ /closed stream/)
	end
end

describe "Socket.pair" do
	let(:sockets) {Socket.pair(:UNIX, :STREAM)}
	let(:client) {IO::Stream::Buffered.wrap(sockets[0])}
	let(:server) {IO::Stream::Buffered.wrap(sockets[1])}
	
	def after(error = nil)
		sockets.each(&:close)
		super
	end
	
	it_behaves_like AUnidirectionalStream
	it_behaves_like ABidirectionalStream
end

describe "OpenSSL::SSL::SSLSocket" do
	include Sus::Fixtures::Async::ReactorContext
	
	include Sus::Fixtures::OpenSSL::VerifiedCertificateContext
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	let(:sockets) {Socket.pair(:UNIX, :STREAM)}
	
	let(:client) {IO::Stream::Buffered.wrap(OpenSSL::SSL::SSLSocket.new(sockets[0], client_context))}
	let(:server) {IO::Stream::Buffered.wrap(OpenSSL::SSL::SSLSocket.new(sockets[1], server_context))}
	
	def before
		super
		
		# Closing the SSLSocket should also close the underlying IO:
		client.io.sync_close = true
		server.io.sync_close = true
		
		[
			Async{server.io.accept},
			Async{client.io.connect}
		].each(&:wait)
	end
	
	def after(error = nil)
		sockets.each(&:close)
		super
	end
	
	it_behaves_like AUnidirectionalStream
	it_behaves_like ABidirectionalStream
end
