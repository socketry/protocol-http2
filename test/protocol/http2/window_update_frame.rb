# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/window_update_frame'
require 'connection_context'
require 'frame_examples'

describe Protocol::HTTP2::WindowUpdateFrame do
	let(:window_size_increment) {1024}
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.pack window_size_increment
			
			super
		end
	end
	
	with '#pack' do
		it "packs data" do
			frame.pack window_size_increment
			
			expect(frame.length).to be == 4
		end
	end
	
	with '#unpack' do
		it "unpacks data" do
			frame.pack window_size_increment
			
			expect(frame.unpack).to be == window_size_increment
		end
	end
	
	with '#read_payload' do
		let(:stream) {StringIO.new([0, 0, 0, 0].pack('C*'))}
		
		with 'a length other than 4' do
			it "raises an error" do
				frame.stream_id = 0
				frame.length = 2
				
				expect{frame.read_payload(stream)}.to raise_exception(
					Protocol::HTTP2::FrameSizeError,
					message: be =~ /Invalid frame length/
				)
			end
		end
	end
	
	with 'a connection' do
		include_context ConnectionContext
		
		let(:framer) {client.framer}
		
		let(:settings) do
			[[Protocol::HTTP2::Settings::INITIAL_WINDOW_SIZE, 200]]
		end
		
		let(:headers) do
			[[':method', 'GET'], [':authority', 'Earth']]
		end
		
		let(:stream) do
			client.create_stream
		end
		
		def before
			client.send_connection_preface do
				server.read_connection_preface(settings)
			end
			
			client.read_frame until client.state == :open
			server.read_frame until server.state == :open
			
			stream.send_headers(nil, headers)
			expect(server.read_frame).to be_a Protocol::HTTP2::HeadersFrame
			
			super
		end
		
		it "can determine available frame size" do
			expect(client.available_frame_size).to be == 16384
			expect(server.available_frame_size).to be == 16384
			
			# Fake the maximum frame size:
			maximum_frame_size = server.available_size + 1
			expect(server.available_frame_size(maximum_frame_size)).to be == server.available_size
			
			expect(stream.maximum_frame_size).to be == 16384
		end
		
		it "can consume data frames" do
			frame = Protocol::HTTP2::DataFrame.new
			frame.length = client.available_size
			
			client.consume_remote_window(frame)
			expect(client.available_size).to be == 0
		end
		
		it "fails if it tries to consume more than the available window" do
			frame = Protocol::HTTP2::DataFrame.new
			frame.length = client.available_size + 1
			
			expect do
				client.consume_remote_window(frame)
			end.to raise_exception(Protocol::HTTP2::FlowControlError, message: be =~ /exceeded window size/)
		end
		
		it "should assign capacity according to settings" do
			expect(client.remote_settings.initial_window_size).to be == 200
			expect(server.local_settings.initial_window_size).to be == 200
			
			expect(client.remote_window.capacity).to be == 0xFFFF
			expect(server.local_window.capacity).to be == 0xFFFF
			
			expect(client.local_window.capacity).to be == 0xFFFF
			expect(server.remote_window.capacity).to be == 0xFFFF
			
			expect(client.local_settings.initial_window_size).to be == 0xFFFF
			expect(server.remote_settings.initial_window_size).to be == 0xFFFF
		end
		
		it "should send window update after exhausting half of the available window" do
			# Write 60 bytes of data.
			stream.send_data("*" * 60)
			
			expect(stream.remote_window.used).to be == 60
			expect(client.remote_window.used).to be == 60
			
			# puts "Server #{server} #{server.remote_window.inspect} reading frame..."
			expect(server.read_frame).to be_a Protocol::HTTP2::DataFrame
			expect(server.local_window.used).to be == 60
			
			# Write another 60 bytes which passes the 50% threshold.
			stream.send_data("*" * 60)
			
			# The server receives a data frame...
			expect(server.read_frame).to be_a Protocol::HTTP2::DataFrame
			
			# ...and must respond with a window update:
			frame = client.read_frame
			expect(frame).to be_a Protocol::HTTP2::WindowUpdateFrame
			
			expect(frame.unpack).to be == 120
		end
		
		with '#expand' do
			it "should expand the window" do
				expect(client.remote_window.used).to be == 0
				expect(client.remote_window.capacity).to be == 0xFFFF
				expect(client.remote_window).not.to be(:full?)
				
				client.remote_window.expand(100)
				
				expect(client.remote_window.used).to be == -100
				expect(client.remote_window.capacity).to be == 0xFFFF
			end
			
			it "should not expand the window beyond the maximum" do
				expect(client.remote_window.used).to be == 0
				expect(client.remote_window.capacity).to be == 0xFFFF
				
				expect do
					client.remote_window.expand(Protocol::HTTP2::MAXIMUM_ALLOWED_WINDOW_SIZE + 1)
				end.to raise_exception(Protocol::HTTP2::FlowControlError)
				
				expect(client.remote_window.used).to be == 0
				expect(client.remote_window.capacity).to be == 0xFFFF
			end
		end
		
		with '#receive_window_update' do
			it "should be invoked when window update is received" do
				# Write 200 bytes of data (client -> server) which exhausts server local window
				stream.send_data("*" * 200)
				
				expect(server.read_frame).to be_a Protocol::HTTP2::DataFrame
				expect(server.local_window.used).to be == 200
				expect(client.remote_window.used).to be == 200
				
				# Window update was sent, and used data was zeroed:
				server_stream = server.streams[stream.id]
				expect(server_stream.local_window.used).to be == 0
				
				# ...and must respond with a window update for the stream:
				expect(stream).to receive(:receive_window_update).once
				frame = client.read_frame
				expect(frame).to be_a Protocol::HTTP2::WindowUpdateFrame
				expect(frame.unpack).to be == 200
			end
			
			it "should be invoked when window update is received for the connection" do
				frame = nil
				
				(client.available_size / 200).times do
					stream.send_data("*" * 200)
					expect(server.read_frame).to be_a Protocol::HTTP2::DataFrame
					frame = client.read_frame
					expect(frame).to be_a Protocol::HTTP2::WindowUpdateFrame
				end
				
				expect(client).to receive(:receive_window_update)
				
				expect(frame).to be_a(Protocol::HTTP2::WindowUpdateFrame)
				expect(frame).to be(:connection?) # stream_id = 0
				
				frame = client.read_frame
				expect(frame).to be_a Protocol::HTTP2::WindowUpdateFrame
				expect(frame).to have_attributes(stream_id: be == stream.id)
				
				stream.send_data("*" * 200)
				expect(server.read_frame).to be_a Protocol::HTTP2::DataFrame
			end
			
			it "should send stream reset if window update is invalid" do
				window_update_frame = Protocol::HTTP2::WindowUpdateFrame.new(stream.id)
				window_update_frame.pack(0)
				
				server.write_frame(window_update_frame)
				
				expect(stream).to receive(:send_reset_stream)
				client.read_frame
			end
			
			it "should fail when window update is received for an idle stream" do
				window_update_frame = Protocol::HTTP2::WindowUpdateFrame.new(stream.id+2)
				window_update_frame.pack(100)
				
				server.write_frame(window_update_frame)
				
				expect do
					frame = client.read_frame
				end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Cannot update window of idle stream/)
			end
		end
	end	
end
