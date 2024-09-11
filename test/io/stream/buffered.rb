# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "io/stream/buffered"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/openssl/verified_certificate_context"
require "sus/fixtures/openssl/valid_certificate_context"

describe IO::Stream::Buffered do
	# This constant is part of the public interface, but was renamed to `Async::IO::BLOCK_SIZE`.
	describe "BLOCK_SIZE" do
		it "should exist and be reasonable" do
			expect(IO::Stream::BLOCK_SIZE).to be_within(1024...1024*128)
		end
	end
	
	describe "MAXIMUM_READ_SIZE" do
		it "should exist and be reasonable" do
			expect(IO::Stream::MAXIMUM_READ_SIZE).to be_within(1024*64..1024*64*512)
		end
	end
end

AUnidirectionalStream = Sus::Shared("a unidirectional stream") do
	it "should be able to read and write data" do
		server.write "Hello, World!"
		server.flush
		
		expect(client.read(13)).to be == "Hello, World!"
	end
	
	describe "#read" do
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
	end
	
	describe "#peek" do
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
	
	describe "#read_exactly" do
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
	end
	
	describe "#read_until" do
		it "can read a line" do
			server.write("hello\nworld\n")
			server.close
			
			expect(client.read_until("\n")).to be == "hello"
			expect(client.read_until("\n")).to be == "world"
			expect(client.read_until("\n")).to be_nil
		end

		with "with 1-byte block size" do
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
	
	describe "#read_partial" do
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
	end
	
	describe "#write" do
		it "should read one line" do
			expect(server).to receive(:syswrite)
			
			server.puts "Hello World"
			server.flush
			
			expect(client.gets).to be == "Hello World"
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
	
	describe "#flush" do
		it "should not call write if write buffer is empty" do
			expect(server).not.to receive(:syswrite)
			
			server.flush
		end

		it "should flush underlying data when it exceeds block size" do
			expect(server).to receive(:syswrite).once
			
			server.block_size = 8
			
			server.block_size.times do
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
			drain_buffer = server.instance_variable_get(:@drain_buffer)
			
			expect(write_buffer).to be(:empty?)
			expect(drain_buffer).to be(:empty?)
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
