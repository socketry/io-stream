require 'io/stream/buffered'
require 'async/clock'

describe IO::Stream::Buffered do
	with "performance (BLOCK_SIZE: #{IO::Stream::BLOCK_SIZE} MAXIMUM_READ_SIZE: #{IO::Stream::MAXIMUM_READ_SIZE})" do
		let(:stream) {subject.open("/dev/zero")}
		
		def after
			stream.close
			
			super
		end
		
		it "can read data quickly" do
			data = nil
			
			duration = Async::Clock.measure do
				data = stream.read(1024**3)
				
				# Compare with:
				# data = stream.io.read(1024**3)
			end
			
			size = data.bytesize / 1024**2
			rate = size / duration
			
			inform "Read #{size.round(2)}MB of data at #{rate.round(2)}MB/s."
			
			expect(rate).to be > 128
		end
	end
end
