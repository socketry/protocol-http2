# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/ping_frame'
require 'frame_examples'

describe Protocol::HTTP2::PingFrame do
	let(:data) {"PingPong"}
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.pack data
			
			super
		end
	end
	
	it "applies to the connection" do
		expect(frame).to be(:connection?)
	end
	
	with '#pack' do
		it "packs data" do
			frame.pack data
			
			expect(frame.length).to be == 8
		end
	end
	
	with '#unpack' do
		it "unpacks data" do
			frame.pack data
			
			expect(frame.unpack).to be == data
		end
	end
	
	with '#read_payload' do
		let(:stream) {StringIO.new([0, 0, 0, 0, 0, 0, 0, 0].pack('C*'))}
		
		with 'invalid stream id' do
			it "raises an error" do
				frame.stream_id = 1
				frame.length = 0
				
				expect{frame.read_payload(stream)}.to raise_exception(
					Protocol::HTTP2::ProtocolError,
					message: be =~ /Settings apply to connection only, but stream_id was given/
				)
			end
		end
		
		with 'a length other than 8' do
			it "raises an error" do
				frame.stream_id = 0
				frame.length = 4
				
				expect{frame.read_payload(stream)}.to raise_exception(
					Protocol::HTTP2::FrameSizeError,
					message: be =~ /Invalid frame length/
				)
			end
		end
	end
end
