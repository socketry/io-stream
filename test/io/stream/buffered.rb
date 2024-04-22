# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'io/stream/buffered'

require 'sus/fixtures/async/reactor_context'
require 'sus/fixtures/openssl/verified_certificate_context'
require 'sus/fixtures/openssl/valid_certificate_context'

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

ABufferedStream = Sus::Shared("a buffered stream") do
	it "should be able to read and write data" do
		writer.write "Hello, World!"
		writer.flush
		
		expect(reader.read(13)).to be == "Hello, World!"
	end
	
	describe '#flush' do
		it "should not call write if write buffer is empty" do
			expect(writer.io).not.to receive(:write)
			
			writer.flush
		end

		it "should flush underlying data when it exceeds block size" do
			expect(writer.io).to receive(:write).once
			
			writer.block_size.times do
				writer.write("!")
			end
		end
	end
	
	with '#eof?' do
		it "should return true when there is no data available" do
			writer.close
			expect(reader.eof?).to be_truthy
		end
		
		it "should return false when there is data available" do
			writer.write "Hello, World!"
			writer.flush
			
			expect(reader.eof?).to be_falsey
		end
	end
	
	with '#readable?' do
		it "should return true when the stream might be open" do
			expect(reader.readable?).to be_truthy
		end
		
		it "should return true when there is data available" do
			writer.write "Hello, World!"
			writer.flush
			
			expect(reader.readable?).to be_truthy
		end
		
		it "should return false when the stream is known to be closed" do
			writer.close
			
			expect(reader.readable?).to be_truthy
			reader.read
			expect(reader.readable?).to be_falsey
		end
	end
	
	with '#close' do
		it "should close the stream" do
			writer.close
			expect(reader.read).to be_nil
			
			expect(writer.closed?).to be_truthy
			expect(reader.closed?).to be_falsey
		end
		
		it "writer should be idempotent" do
			writer.close
			writer.close
			
			expect(writer.closed?).to be_truthy
			expect(reader.closed?).to be_falsey
		end
		
		it "reader be idempotent" do
			reader.close
			reader.close
			
			expect(reader.closed?).to be_truthy
			expect(writer.closed?).to be_falsey
		end
	end
end

describe "IO.pipe" do
	let(:pipe) {IO.pipe}
	let(:reader) {IO::Stream::Buffered.wrap(pipe[0])}
	let(:writer) {IO::Stream::Buffered.wrap(pipe[1])}
	
	def after
		pipe.each(&:close)
		super
	end
	
	it_behaves_like ABufferedStream
end

describe "Socket.pair" do
	let(:sockets) {Socket.pair(:UNIX, :STREAM)}
	let(:reader) {IO::Stream::Buffered.wrap(sockets[0])}
	let(:writer) {IO::Stream::Buffered.wrap(sockets[1])}
	
	def after
		sockets.each(&:close)
		super
	end
	
	it_behaves_like ABufferedStream
end

describe "OpenSSL::SSL::SSLSocket" do
	include Sus::Fixtures::Async::ReactorContext
	
	include Sus::Fixtures::OpenSSL::VerifiedCertificateContext
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	let(:sockets) {Socket.pair(:UNIX, :STREAM)}
	
	let(:reader) {IO::Stream::Buffered.wrap(OpenSSL::SSL::SSLSocket.new(sockets[0], client_context))}
	let(:writer) {IO::Stream::Buffered.wrap(OpenSSL::SSL::SSLSocket.new(sockets[1], server_context))}
	
	def before
		super
		
		# Closing the SSLSocket should also close the underlying IO:
		reader.io.sync_close = true
		writer.io.sync_close = true
		
		[
			Async{writer.io.accept},
			Async{reader.io.connect}
		].each(&:wait)
	end
	
	def after
		sockets.each(&:close)
		super
	end
	
	it_behaves_like ABufferedStream
end
