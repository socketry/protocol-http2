# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "protocol/http2/connection_context"

describe Protocol::HTTP2::Stream do
	include_context Protocol::HTTP2::ConnectionContext
	
	def before
		client.open!
		server.open!
		
		super
	end
	
	it "can create a stream" do
		stream = client.create_stream
		expect(stream).to be_a(Protocol::HTTP2::Stream)
	end
	
	it "can create a stream with a block" do
		stream = client.create_stream do |connection, stream_id|
			expect(connection).to be_equal(client)
			expect(stream_id).to be_a(Integer)
			
			[connection, stream_id]
		end
		
		expect(stream).to be == [client, 1]
	end
	
	with "idle stream" do
		let(:stream) {client.create_stream}
		
		it "is not active" do
			expect(stream).not.to be(:active?)
		end
		
		it "can send headers" do
			expect(stream).to be(:send_headers?)
		end
		
		it "can't receive stream reset" do
			frame = Protocol::HTTP2::ResetStreamFrame.new(stream.id)
			
			expect do
				stream.receive_reset_stream(frame)
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot receive reset stream/)
		end
		
		it "can inspect the stream" do
			expect(stream.inspect).to be =~ /id=1 state=idle/
		end
		
		it "can send headers" do
			stream.send_headers([["foo", "bar"]])
			
			# Pre-create the stream in idle state:
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_headers)
			
			frame = server.read_frame
			expect(frame).to be_a(Protocol::HTTP2::HeadersFrame)
			expect(frame).not.to be(:end_stream?)
		end
		
		it "can send request and read response" do
			stream.send_headers([["foo", "bar"]], Protocol::HTTP2::END_STREAM)
			
			server_stream = server.create_stream(stream.id)
			
			expect(server_stream).to receive(:receive_headers)
			
			server.read_frame
			
			expect(server_stream.state).to be == :half_closed_remote
			
			server_stream.send_headers([[":status", "200"]])
			frame = client.read_frame
			expect(frame).to be_a(Protocol::HTTP2::HeadersFrame)
			expect(frame).not.to be(:end_stream?)
			
			server_stream.send_data("Hello World!", Protocol::HTTP2::END_STREAM)
			frame = client.read_frame
			expect(frame).to be_a(Protocol::HTTP2::DataFrame)
			expect(frame).to be(:end_stream?)
		end
		
		it "cannot send data" do
			expect do
				stream.send_data("Hello World!")
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send data in state: idle/)
		end
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send reset stream/)
		end
		
		it "cannot receive data" do
			stream.open!
			stream.send_data("Hello World!")
			
			expect do
				server.read_frame
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot receive data/)
		end
		
		it "cannot receive stream reset" do
			stream.open!
			stream.send_reset_stream
			
			expect do
				server.read_frame
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot reset stream/)
		end
	end
	
	with "open stream" do
		let(:stream) {client.create_stream}
		let(:headers) {[[":method", "GET"], [":path", "/"], [":scheme", "https"], [":authority", "example.com"]]}
		let(:server_stream) {server[stream.id]}
		
		def before
			stream.send_headers(headers)
			server.read_frame
			
			super
		end
		
		it "is active" do
			expect(stream).to be(:active?)
		end
		
		it "can send data" do
			stream.send_data("Hello World!")
			
			expect(server_stream).to receive(:receive_data).and_return(nil)
			
			server.read_frame
		end
		
		it "can send reset stream" do
			stream.send_reset_stream
			
			expect(server_stream).to receive(:receive_reset_stream).and_return(nil)
			
			server.read_frame
		end
		
		it "can send request trailers" do
			stream.send_headers([["foo", "bar"]], Protocol::HTTP2::END_STREAM)
			
			expect(server_stream).to receive(:receive_headers)
			server.read_frame
			
			expect(server_stream.state).to be == :half_closed_remote
		end
		
		it "can send response and end stream" do
			server_stream.send_headers([["foo", "bar"]], Protocol::HTTP2::END_STREAM)
			
			expect(stream).to receive(:receive_headers)
			client.read_frame
			
			expect(stream.state).to be == :half_closed_remote
		end
		
		it "can't be opened (again)" do
			expect do
				stream.open!
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot open stream/)
		end
	end
	
	with "half closed local stream" do
		let(:stream) {client.create_stream}
		let(:headers) {[[":method", "GET"], [":path", "/"], [":scheme", "https"], [":authority", "example.com"]]}
		let(:server_stream) {server[stream.id]}
		
		def before
			stream.send_headers(headers, Protocol::HTTP2::END_STREAM)
			server.read_frame
			
			super
		end
		
		it "is active" do
			expect(stream).to be(:active?)
		end
		
		it "can send data from server side" do
			expect(server_stream.state).to be == :half_closed_remote
			
			server_stream.send_data("Hello World!", Protocol::HTTP2::END_STREAM)
			expect(server_stream).to be(:closed?)
			
			expect(stream).to receive(:receive_data).and_return(nil)
			client.read_frame
		end
		
		it "can't send data" do
			expect do
				stream.send_data("Hello World!")
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send data in state: half_closed_local/)
		end
	end
	
	with "pushed stream" do
		let(:origin_stream) {client.create_stream}
		let(:server_stream) {server[origin_stream.id]}
		
		let(:promised_stream) {@promised_stream}
		let(:stream) {client[@pushed_stream_id]}
		let(:headers) {[[":method", "GET"], [":path", "/"], [":scheme", "https"], [":authority", "example.com"]]}
		let(:response_headers) {[[":status", "200"]]}
		
		def before
			origin_stream.send_headers(headers)
			server.read_frame
			
			@promised_stream = server_stream.send_push_promise(headers)
			frame = client.read_frame
			
			@pushed_stream_id, data = frame.unpack
			
			super
		end
		
		it "can't send headers" do
			expect(stream).not.to be(:send_headers?)
			
			expect do
				stream.send_headers([["foo", "bar"]])
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send headers in state: reserved_remote/)
		end
		
		it "receives stream reset when writing headers in invalid state" do
			stream.state = :open
			
			stream.send_headers([["foo", "bar"]])
			frame = server.read_frame
			
			frame = client.read_frame
			expect(frame).to be_a(Protocol::HTTP2::ResetStreamFrame)
		end
		
		it "receives stream reset when writing data in invalid state" do
			stream.state = :open
			
			stream.send_data("Hello World!")
			frame = server.read_frame
			
			frame = client.read_frame
			expect(frame).to be_a(Protocol::HTTP2::ResetStreamFrame)
		end
		
		it "can send response and end stream" do
			promised_stream.send_headers(response_headers, Protocol::HTTP2::END_STREAM)
			expect(promised_stream.state).to be == :half_closed_remote
			
			expect(stream).to receive(:receive_headers)
			client.read_frame
			
			expect(stream.state).to be == :half_closed_local
		end
	end
	
	with "closed stream" do
		let(:stream) {client.create_stream.close!}
		
		it "is not active" do
			expect(stream).not.to be(:active?)
		end
		
		it "can't send headers" do
			expect(stream).not.to be(:send_headers?)
			
			expect do
				stream.send_headers([["foo", "bar"]])
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send headers in state: closed/)
		end
		
		it "cannot send reset stream" do
			expect do
				stream.send_reset_stream
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send reset stream/)
		end
		
		it "won't accept the same stream" do
			expect do
				client.accept_stream(stream.id)
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Invalid stream id/)
		end
		
		it "cannot reserve local" do
			expect do
				stream.reserved_local!
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot reserve stream/)
		end
		
		it "cannot reserve remote" do
			expect do
				stream.reserved_remote!
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot reserve stream/)
		end
		
		it "cannot send push promise" do
			expect do
				stream.send_push_promise([])
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot send push promise/)
		end
		
		it "ignores headers" do
			expect(stream).to receive(:ignore_headers)
			
			stream.receive_headers(nil)
		end
		
		it "ignores data" do
			expect(stream).to receive(:ignore_data)
			
			stream.receive_data(nil)
		end
		
		it "ignores reset stream" do
			server_stream = server.create_stream(stream.id)
			server_stream.open!
			server_stream.send_reset_stream
			
			client.read_frame
		end
	end
end
