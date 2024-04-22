require 'io/readable'

describe IO do
	let(:io) {IO.new(IO.sysopen('/dev/null', 'w'))}
	
	it "should be readable" do
		expect(io).to be(:readable?)
	end
	
	it "should not be readable after closing" do
		io.close
	
		expect(io).not.to be(:readable?)
	end
end

describe TCPSocket do
	let(:client) {@client}
	
	attr :server
	
	def before
		@server = TCPServer.new('localhost', 0)
		@client = TCPSocket.new('localhost', @server.local_address.ip_port)
	end
	
	def after
		@server.close
		@client&.close
		
		super
	end
	
	it "should be readable" do
		expect(client).to be(:readable?)
	end
	
	it "should not be readable after closing" do
		client.close
	
		expect(client).not.to be(:readable?)
	end
	
	it "should not be readable after closing server" do
		server.close
	
		expect(client).not.to be(:readable?)
	end
end

describe StringIO do
	let(:io) {StringIO.new}
	
	with "empty buffer" do
		it "should not be readable" do
			expect(io).not.to be(:readable?)
		end
	end
	
	with "non-empty buffer" do
		it "should be readable" do
			io.write("Hello, World!")
			io.rewind
			
			expect(io).to be(:readable?)
		end
		
		it "should be readable after reading" do
			io.write("Hello, World!")
			io.rewind
			
			io.read(5)
			
			expect(io).to be(:readable?)
		end
		
		it "should not be readable after reading all" do
			io.write("Hello, World!")
			io.rewind
			
			io.read
			
			expect(io).not.to be(:readable?)
		end
	end
end
