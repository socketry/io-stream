#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "bundler/inline"

gemfile do
	source "https://rubygems.org"
	gem "async"
end

require "socket"

def close_while_reading(io)
	thread = Thread.new do
		Thread.current.report_on_exception = false
		io.wait_readable
	end
	
	# Wait until the thread is blocked on read:
	Thread.pass until thread.status == "sleep"
	
	Async do
		io.close
	end
	
	thread.join
end

begin
	client, server = Socket.pair(:UNIX, :STREAM)
	close_while_reading(client)
rescue => error
	$stderr.puts error.full_message
end
