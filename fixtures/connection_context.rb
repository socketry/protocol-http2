# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/client'
require 'protocol/http2/server'
require 'protocol/http2/stream'

require 'socket'

ConnectionContext = Sus::Shared("a connection") do
	let(:sockets) {Socket.pair(Socket::PF_UNIX, Socket::SOCK_STREAM)}
	
	let(:client) {Protocol::HTTP2::Client.new(Protocol::HTTP2::Framer.new(sockets.first))}
	let(:server) {Protocol::HTTP2::Server.new(Protocol::HTTP2::Framer.new(sockets.last))}
end
