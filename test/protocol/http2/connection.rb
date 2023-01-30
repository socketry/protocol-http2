# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.
# Copyright, 2023, by Marco Concetto Rudilosso.

require_relative 'connection_context'

RSpec.describe Protocol::HTTP2::Connection do
	include_context Protocol::HTTP2::Connection
	
	it "can negotiate connection" do
		first_server_frame = nil
		
		first_client_frame = client.send_connection_preface do
			first_server_frame = server.read_connection_preface([])
		end
		
		expect(first_client_frame).to be_kind_of Protocol::HTTP2::SettingsFrame
		expect(first_client_frame).to_not be_acknowledgement
		
		expect(first_server_frame).to be_kind_of Protocol::HTTP2::SettingsFrame
		expect(first_server_frame).to_not be_acknowledgement
		
		frame = client.read_frame
		expect(frame).to be_kind_of Protocol::HTTP2::SettingsFrame
		expect(frame).to be_acknowledgement
		
		frame = server.read_frame
		expect(frame).to be_kind_of Protocol::HTTP2::SettingsFrame
		expect(frame).to be_acknowledgement
		
		expect(client.state).to eq :open
		expect(server.state).to eq :open
	end
	
	context Protocol::HTTP2::PingFrame do
		before do
			client.open!
			server.open!
		end
		
		it "can send ping and receive pong" do
			expect(server).to receive(:receive_ping).once.and_call_original
			
			client.send_ping("12345678")
			
			server.read_frame
			
			expect(client).to receive(:receive_ping).once.and_call_original
			
			client.read_frame
		end
	end
	
	context Protocol::HTTP2::Stream do
		before do
			client.open!
			server.open!
		end
		
		let(:request_data) {"Hello World!"}
		let(:stream) {client.create_stream}
		
		let(:request_headers) {[[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]}
		let(:response_headers) {[[':status', '200']]}
		
		it "can create new stream and send response" do
			stream.send_headers(nil, request_headers)
			expect(stream.id).to eq 1
			
			expect(server).to receive(:receive_headers).once.and_wrap_original do |method, frame|
				headers = method.call(frame)
				
				expect(headers).to be == request_headers
			end
			
			server.read_frame
			expect(server.streams).to_not be_empty
			expect(server.streams[1].state).to be :open
			
			stream.send_data(request_data, Protocol::HTTP2::END_STREAM)
			expect(stream.state).to eq :half_closed_local
			
			expect(server).to receive(:receive_data).and_call_original
			
			data_frame = server.read_frame
			expect(data_frame.unpack).to be == request_data
			expect(server.streams[1].state).to be :half_closed_remote
			
			server.streams[1].send_headers(nil, response_headers, Protocol::HTTP2::END_STREAM)
			
			expect(stream).to receive(:process_headers).once.and_wrap_original do |method, frame|
				headers = method.call(frame)
				
				expect(headers).to be == response_headers
			end
			
			client.read_frame
			expect(stream.state).to eq :closed
			
			expect(stream.remote_window.used).to eq data_frame.length
		end
		
		it "client can handle graceful shutdown" do
			stream.send_headers(nil, request_headers, Protocol::HTTP2::END_STREAM)
			
			# Establish request stream on server:
			server.read_frame
			
			# Graceful shutdown
			server.send_goaway(0)
			
			expect(client.read_frame).to be_a Protocol::HTTP2::GoawayFrame
			expect(client.remote_stream_id).to be == 1
			expect(client).to be_closed
			
			expect(server.streams[1].state).to eq :half_closed_remote
			
			server.streams[1].send_headers(nil, response_headers, Protocol::HTTP2::END_STREAM)
			
			client.read_frame
			
			expect(stream.state).to eq :closed
		end
		
		it "client can handle non-graceful shutdown" do
			stream.send_headers(nil, request_headers, Protocol::HTTP2::END_STREAM)
			
			# Establish request stream on server:
			server.read_frame
			
			# Send connection error to client:
			server.send_goaway(1, "Bugger off!")
			
			expect(stream).to receive(:close).and_call_original
			
			expect do
				client.read_frame
			end.to raise_error(Protocol::HTTP2::GoawayError)
			
			client.close
			
			expect(client.remote_stream_id).to be == 1
			expect(client).to be_closed
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
			expect(frame).to be_end_stream
		end
	end

	it "allows client to create new stream and send headers when client maximum concurrent streams is 0" do
		client.local_settings.current.maximum_concurrent_streams = 0
		client_stream = client.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		client_stream.send_headers(nil, request_headers)

		expect(server).to receive(:receive_headers).once.and_wrap_original do |method, frame|
			headers = method.call(frame)

			expect(headers).to be == request_headers
		end

		server.read_frame
	end

	it "does not allow client to create new stream and send headers when server maximum concurrent streams is 0" do
		server.local_settings.current.maximum_concurrent_streams = 0
		client_stream = client.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		client_stream.send_headers(nil, request_headers)

		expect { server.read_frame }.to raise_error(Protocol::HTTP2::ProtocolError)
	end

	it "allows server to create new stream and send headers when server maximum concurrent streams is 0" do
		server.local_settings.current.maximum_concurrent_streams = 0
		server_stream = server.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		server_stream.send_headers(nil, request_headers)

		expect(client).to receive(:receive_headers).once.and_wrap_original do |method, frame|
			headers = method.call(frame)

			expect(headers).to be == request_headers
		end

		client.read_frame
	end

	it "does not allow server to create new stream send headers when client maximum concurrent streams is 0" do
		client.local_settings.current.maximum_concurrent_streams = 0
		server_stream = server.create_stream
		request_headers = [[':method', 'GET'], [':path', '/'], [':authority', 'localhost']]
		server_stream.send_headers(nil, request_headers)

		expect { client.read_frame }.to raise_error(Protocol::HTTP2::ProtocolError)
	end
end
