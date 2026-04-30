# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "io/stream"

describe IO::Stream::Duplex do
	def make_pipes
		server_input, client_output = IO.pipe
		client_input, server_output = IO.pipe
		
		{
			server_input: server_input,
			server_output: server_output,
			client_input: client_input,
			client_output: client_output,
		}
	end
	
	with ".new" do
		it "wraps distinct input and output streams" do
			pipes = make_pipes
			
			begin
				stream = subject.new(pipes[:client_input], pipes[:client_output])
				
				expect(stream.input).to be_equal(pipes[:client_input])
				expect(stream.output).to be_equal(pipes[:client_output])
				expect(stream.input).not.to be_equal(stream.output)
			ensure
				pipes.each_value(&:close)
			end
		end
	end
	
	with "::Duplex" do
		it "wraps a single duplex IO directly" do
			io = StringIO.new
			
			stream = IO::Stream::Duplex(io)
			
			expect(stream).to be_a(IO::Stream::Buffered)
			expect(stream.io).to be_equal(io)
		end
		
		it "returns a buffered stream wrapping a duplex IO" do
			pipes = make_pipes
			
			begin
				stream = IO::Stream::Duplex(pipes[:client_input], pipes[:client_output])
				
				expect(stream).to be_a(IO::Stream::Buffered)
				expect(stream.io).to be_a(subject)
				expect(stream.io.input).to be_equal(pipes[:client_input])
				expect(stream.io.output).to be_equal(pipes[:client_output])
			ensure
				stream&.close
				pipes.each_value.each do |io|
					io.close unless io.closed?
				end
			end
		end
	end
	
	with "#read and #write" do
		it "reads from input and writes to output" do
			pipes = make_pipes
			
			begin
				stream = IO::Stream::Duplex(pipes[:client_input], pipes[:client_output])
				
				stream.write("hello")
				stream.flush
				
				expect(pipes[:server_input].read(5)).to be == "hello"
				
				pipes[:server_output].write("world")
				pipes[:server_output].close
				
				expect(stream.read(5)).to be == "world"
			ensure
				stream&.close rescue nil
				pipes.each_value.each do |io|
					io.close unless io.closed?
				end
			end
		end
		
	end
	
	with "#close_write" do
		it "closes only the write side" do
			pipes = make_pipes
			
			begin
				stream = IO::Stream::Duplex(pipes[:client_input], pipes[:client_output])
				
				stream.write("hello")
				stream.close_write
				
				expect(pipes[:server_input].read).to be == "hello"
				expect(pipes[:client_input]).not.to be(:closed?)
			ensure
				stream.close_read rescue nil
				pipes.each_value.each do |io|
					io.close unless io.closed?
				end
			end
		end
	end
	
	with "#close" do
		it "closes both sides when input and output are distinct" do
			pipes = make_pipes
			
			begin
				stream = IO::Stream::Duplex(pipes[:client_input], pipes[:client_output])
				stream.close
				
				expect(stream).to be(:closed?)
				expect(pipes[:client_input]).to be(:closed?)
				expect(pipes[:client_output]).to be(:closed?)
			ensure
				pipes.each_value.each do |io|
					io.close unless io.closed?
				end
			end
		end
	end
end
