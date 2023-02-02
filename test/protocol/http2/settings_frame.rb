# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/settings_frame'
require 'frame_examples'

describe Protocol::HTTP2::SettingsFrame do
	let(:settings) {[
		[3, 10], [5, 1048576], [4, 2147483647], [8, 1]
	]}
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.pack settings
			
			super
		end
	end
	
	it "applies to the connection" do
		expect(frame).to be(:connection?)
	end
	
	with '#pack' do
		it "packs settings" do
			frame.pack settings
			
			expect(frame.length).to be == 6*settings.size
		end
	end
	
	with '#unpack' do
		it "unpacks settings" do
			frame.pack settings
			
			expect(frame.unpack).to be == settings
		end
		
		it "can generate acknowledgment" do
			frame.pack settings
			acknowledgement_frame = frame.acknowledge
			
			expect(acknowledgement_frame).to be_a(Protocol::HTTP2::SettingsFrame)
			expect(acknowledgement_frame).to be(:acknowledgement?)
			expect(acknowledgement_frame.length).to be == 0
			
			settings = acknowledgement_frame.unpack
			expect(settings).to be == []
		end
		
		it "can unpack empty settings" do
		end
	end
	
	with '#read_payload' do
		let(:stream) {StringIO.new([0, 0, 0, 0, 0, 0].pack('C*'))}
		
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
		
		with 'non-zero length acknowledgement' do
			it "raises an error" do
				frame.acknowledgement!
				frame.stream_id = 0
				frame.length = 6
				
				expect{frame.read_payload(stream)}.to raise_exception(
					Protocol::HTTP2::ProtocolError,
					message: be =~ /Settings acknowledgement must not contain payload/
				)
			end
		end
		
		with 'invalid length modulo 6' do
			it "raises an error" do
				frame.stream_id = 0
				frame.length = 5
				
				expect{frame.read_payload(stream)}.to raise_exception(
					Protocol::HTTP2::ProtocolError,
					message: be =~ /Invalid frame length/
				)
			end
		end
	end
end
