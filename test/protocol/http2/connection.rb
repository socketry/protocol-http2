# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.
# Copyright, 2023, by Marco Concetto Rudilosso.

require 'connection_context'

describe Protocol::HTTP2::Connection do
	include_context ConnectionContext
	
	with 'stream id 0' do
		it "can determine closed streams" do
			expect(client).not.to be(:closed_stream_id?, 0)
		end
	end
	
	it "can negotiate connection" do
		first_server_frame = nil
		
		first_client_frame = client.send_connection_preface do
			first_server_frame = server.read_connection_preface([])
		end
		
		expect(first_client_frame).to be_a Protocol::HTTP2::SettingsFrame
		expect(first_client_frame).not.to be(:acknowledgement?)
		
		expect(first_server_frame).to be_a Protocol::HTTP2::SettingsFrame
		expect(first_server_frame).not.to be(:acknowledgement?)
		
		frame = client.read_frame
		expect(frame).to be_a Protocol::HTTP2::SettingsFrame
		expect(frame).to be(:acknowledgement?)
		
		frame = server.read_frame
		expect(frame).to be_a Protocol::HTTP2::SettingsFrame
		expect(frame).to be(:acknowledgement?)
		
		expect(client.state).to be == :open
		expect(server.state).to be == :open
	end
	
	describe Protocol::HTTP2::PingFrame do
		def before
			client.open!
			server.open!
			
			super
		end
		
		it "can send ping and receive pong" do
			expect(server).to receive(:receive_ping)
			
			client.send_ping("12345678")
			
			server.read_frame
			
			expect(client).to receive(:receive_ping)
			
			client.read_frame
		end
	end
	
	describe Protocol::HTTP2::Stream do
		def before
			client.open!
			server.open!
			
			super
		end
		
		let(:request_data) {"Hello World!"}
		let(:stream) {client.create_stream}
		
		let(:request_headers) {[[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]}
		let(:response_headers) {[[':status', '200']]}
		
		it "can determine who initiated stream" do
			expect(client).to be(:client_stream_id?, stream.id)
			expect(client).not.to be(:server_stream_id?, stream.id)
		end
		
		it "can determine closed streams" do
			expect(client).not.to be(:idle_stream_id?, stream.id)
			expect(server).to be(:idle_stream_id?, stream.id)
			
			stream.send_headers(nil, request_headers)
			
			server.read_frame
			
			# `closed_stream_id?` is true even if the stream is still open. It implies that if the stream is not otherwise open, it is closed.
			expect(server[stream.id]).not.to be_nil
			expect(server).to be(:closed_stream_id?, stream.id)
		end
		
		it "can create new stream and send response" do
			stream.send_headers(nil, request_headers)
			expect(stream.id).to be == 1
			
			expect(server).to receive(:receive_headers) do |frame|
				headers = super(frame)
				
				expect(headers).to be == request_headers
			end
			
			server.read_frame
			expect(server.streams).not.to be(:empty?)
			expect(server.streams[1].state).to be == :open
			
			stream.send_data(request_data, Protocol::HTTP2::END_STREAM)
			expect(stream.state).to be == :half_closed_local
			
			expect(server).to receive(:receive_data)
			
			data_frame = server.read_frame
			expect(data_frame.unpack).to be == request_data
			expect(server.streams[1].state).to be == :half_closed_remote
			
			server.streams[1].send_headers(nil, response_headers, Protocol::HTTP2::END_STREAM)
			
			expect(stream).to receive(:process_headers) do |frame|
				headers = super(frame)
				
				expect(headers).to be == response_headers
			end
			
			client.read_frame
			expect(stream.state).to be == :closed
			
			expect(stream.remote_window.used).to be == data_frame.length
		end
		
		it "client can handle graceful shutdown" do
			stream.send_headers(nil, request_headers, Protocol::HTTP2::END_STREAM)
			
			# Establish request stream on server:
			server.read_frame
			
			# Graceful shutdown
			server.send_goaway(0)
			
			another_stream = client.create_stream
			another_stream.send_headers(nil, request_headers, Protocol::HTTP2::END_STREAM)
			
			expect(client.read_frame).to be_a Protocol::HTTP2::GoawayFrame
			expect(client.remote_stream_id).to be == 1
			expect(client).to be(:closed?)
			
			# The server will ignore this frame as it was sent after the graceful shutdown:
			server.read_frame
			expect(server.streams[another_stream.id]).to be_nil
			
			# The pre-existing stream is still functional:
			expect(server.streams[1].state).to be == :half_closed_remote
			
			server.streams[1].send_headers(nil, response_headers, Protocol::HTTP2::END_STREAM)
			
			client.read_frame
			
			expect(stream.state).to be == :closed
		end
		
		it "client can handle non-graceful shutdown" do
			stream.send_headers(nil, request_headers, Protocol::HTTP2::END_STREAM)
			
			# Establish request stream on server:
			server.read_frame
			
			# Send connection error to client:
			server.send_goaway(1, "Bugger off!")
			
			expect(stream).to receive(:close)
			
			expect do
				client.read_frame
			end.to raise_exception(Protocol::HTTP2::GoawayError)
			
			client.close
			
			expect(client.remote_stream_id).to be == 1
			expect(client).to be(:closed?)
		end
		
		it "can stream data" do
			stream.send_headers(nil, request_headers)
			stream.send_data("A")
			stream.send_data("B")
			stream.send_data("C")
			stream.send_data("", Protocol::HTTP2::END_STREAM)
			
			frame = server.read_frame
			expect(frame).to be_a(Protocol::HTTP2::HeadersFrame)
			
			expect(stream.available_frame_size).to be >= 3
			
			frame = server.read_frame
			expect(frame).to be_a(Protocol::HTTP2::DataFrame)
			expect(frame.unpack).to be == "A"
			
			frame = server.read_frame
			expect(frame).to be_a(Protocol::HTTP2::DataFrame)
			expect(frame.unpack).to be == "B"
			
			frame = server.read_frame
			expect(frame).to be_a(Protocol::HTTP2::DataFrame)
			expect(frame.unpack).to be == "C"
			
			frame = server.read_frame
			expect(frame).to be_a(Protocol::HTTP2::DataFrame)
			expect(frame.unpack).to be == ""
			expect(frame).to be(:end_stream?)
		end
	end

	it "allows client to create new stream and send headers when client maximum concurrent streams is 0" do
		client.local_settings.current.maximum_concurrent_streams = 0
		client_stream = client.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		client_stream.send_headers(nil, request_headers)

		expect(server).to receive(:receive_headers) do |frame|
			headers = super(frame)

			expect(headers).to be == request_headers
		end

		server.read_frame
	end

	it "does not allow client to create new stream and send headers when server maximum concurrent streams is 0" do
		server.local_settings.current.maximum_concurrent_streams = 0
		client_stream = client.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		client_stream.send_headers(nil, request_headers)

		expect { server.read_frame }.to raise_exception(Protocol::HTTP2::ProtocolError)
	end

	it "allows server to create new stream and send headers when server maximum concurrent streams is 0" do
		server.local_settings.current.maximum_concurrent_streams = 0
		server_stream = server.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		server_stream.send_headers(nil, request_headers)

		expect(client).to receive(:receive_headers) do |frame|
			headers = super(frame)

			expect(headers).to be == request_headers
		end

		client.read_frame
	end

	it "does not allow server to create new stream send headers when client maximum concurrent streams is 0" do
		client.local_settings.current.maximum_concurrent_streams = 0
		server_stream = server.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		server_stream.send_headers(nil, request_headers)

		expect { client.read_frame }.to raise_exception(Protocol::HTTP2::ProtocolError)
	end
end
