# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/stream/buffered"
require "objspace"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/openssl/verified_certificate_context"
require "sus/fixtures/openssl/valid_certificate_context"

describe IO::Stream::Buffered do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::OpenSSL::VerifiedCertificateContext
	include Sus::Fixtures::OpenSSL::ValidCertificateContext
	
	before do
		listener = TCPServer.new("localhost", 0)
		port = listener.local_address.ip_port
		
		@sockets = [
			TCPSocket.new("localhost", port),
			listener.accept,
		]
		listener.close
		
		client = OpenSSL::SSL::SSLSocket.new(@sockets[0], client_context)
		server = OpenSSL::SSL::SSLSocket.new(@sockets[1], server_context)
		
		client.sync_close = true
		server.sync_close = true
		
		accept = Async do
			server.accept
		end
		
		connect = Async do
			client.connect
		end
		
		[accept, connect].each(&:wait)
		
		@client = IO::Stream::Buffered.wrap(client)
		@server = IO::Stream::Buffered.wrap(server)
	end
	
	after do
		@client&.close
		@server&.close
		@sockets.each do |socket|
			unless socket.closed?
				socket.close
			end
		end
	end
	
	attr :client
	attr :server
	
	it "detects a TLS close notification" do
		closing = reactor.async do
			server.close
		end
		
		@sockets[0].wait_readable(1)
		
		expect(client.peek_partial(1)).to be_nil
		expect(client).not.to be(:readable?)
		expect(client.peek_partial(0)).to be == ""
		closing.wait
	end
	
	it "detects an abrupt TLS connection close" do
		@sockets.last.close
		@server = nil
		
		@sockets.first.wait_readable(1)
		
		expect do
			client.peek_partial(1)
		end.to raise_exception(OpenSSL::SSL::SSLError)
	end
	
	it "reports when reading an open TLS connection would block" do
		expect(client.peek_partial(0)).to be == ""
		expect(client.peek_partial(1)).to be_nil
		expect(client).to be(:readable?)
	end
	
	it "preserves data consumed by the readability probe" do
		server.write("Hello")
		server.flush
		
		@sockets[0].wait_readable(1)
		
		expect(client.peek_partial(0)).to be == ""
		expect(client.peek_partial(1)).to be == "H"
		expect(client.peek(0)).to be == ""
		expect(client.read(5)).to be == "Hello"
	end
	
	it "sizes a chunk to the TLS record it came from" do
		record = "x" * IO::Stream::Buffered::TLS_RECORD_SIZE
		server.write(record)
		server.flush
		
		chunk = client.read_partial
		
		expect(chunk).to be == record
		expect(ObjectSpace.memsize_of(chunk)).to be < 4 * record.bytesize
	end
	
	it "reads data spanning many TLS records" do
		data = Random.new(1).bytes(1024 * 1024)
		writer = reactor.async do
			server.write(data)
			server.close
		end
		
		expect(client.read.b).to be == data
		writer.wait
	end
	
	# Record calls to the real SSL implementation without changing its behavior.
	def record_read_sizes(io)
		sizes = []
		io.singleton_class.prepend(Module.new do
			define_method(:read_nonblock) do |size, *arguments, **options|
				sizes << size
				super(size, *arguments, **options)
			end
		end)
		return sizes
	end
	
	[1024, 16 * 1024, 16 * 1024 + 1, 256 * 1024].each do |requested|
		with "a requested read size of #{requested}", unique: requested do
			it "caps blocking TLS reads without increasing smaller requests" do
				sizes = record_read_sizes(client.io)
				client.minimum_read_size = requested
				server.write("hello")
				server.flush
				
				expect(client.read_partial).to be == "hello"
				expect(sizes).not.to be(:empty?)
				expect(sizes.uniq).to be == [[requested, 16 * 1024].min]
			end
			
			it "caps nonblocking TLS probes without increasing smaller requests" do
				sizes = record_read_sizes(client.io)
				
				# With no application data, this must return immediately and retain readability.
				expect(client.peek_partial(requested)).to be_nil
				expect(client).to be(:readable?)
				expect(sizes).to be == [[requested, 16 * 1024].min]
			end
		end
	end
	
	it "preserves a full record read by a nonblocking probe" do
		data = "x".b * (16 * 1024)
		server.write(data)
		server.flush
		@sockets.first.wait_readable(1)
		
		expect(client.peek_partial(256 * 1024)).to be == data
		chunk = client.read_partial
		expect(chunk).to be == data
		expect(ObjectSpace.memsize_of(chunk)).to be < 4 * data.bytesize
	end
	
	it "honors a configured maximum smaller than a TLS record" do
		sizes = record_read_sizes(client.io)
		stream = IO::Stream::Buffered.new(client.io, maximum_read_size: 1024)
		
		expect(stream.peek_partial(256 * 1024)).to be_nil
		server.write("hello")
		server.flush
		expect(stream.read_partial).to be == "hello"
		expect(sizes.uniq).to be == [1024]
	end
	
	it "fills a caller-owned buffer across record boundaries and handles EOF" do
		data = Random.new(2).bytes(16 * 1024 * 3 + 123)
		writer = reactor.async do
			server.write(data)
			server.close
		end
		buffer = +"old contents"
		
		expect(client.read(data.bytesize, buffer)).to be_equal(buffer)
		expect(buffer).to be == data
		expect(client.read_partial).to be_nil
		expect(client).not.to be(:readable?)
		writer.wait
	end
end
