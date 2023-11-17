
require 'io/buffered'

describe IO do
	let(:io) {IO.new(IO.sysopen('/dev/null', 'w'))}
	
	it "should be buffered by default" do
		expect(io).to be(:buffered?)
	end
	
	it "should be able to set buffering" do
		io.buffered = false
		
		expect(io).not.to be(:buffered?)
	end
end

describe TCPSocket do
	let(:client) {@client = TCPSocket.new('localhost', @server.local_address.ip_port)}
	
	def before
		@server = TCPServer.new('localhost', 0)
	end
	
	def after
		@server.close
		@client&.close
		
		super
	end
	
	it "should not be buffered by default" do
		expect(client).not.to be(:buffered?)
	end
end
