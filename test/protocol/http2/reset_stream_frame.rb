# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/reset_stream_frame'
require 'frame_examples'

describe Protocol::HTTP2::ResetStreamFrame do
	let(:error) {Protocol::HTTP2::INTERNAL_ERROR}
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.pack error
			
			super
		end
	end
	
	with '#pack' do
		it "packs error" do
			frame.pack error
			expect(frame.length).to be == 4
		end
	end
	
	with '#unpack' do
		it "unpacks error" do
			frame.pack error
			expect(frame.unpack).to be == error
		end
	end
	
	with '#read_payload' do
		let(:stream) {StringIO.new("!!!")}
		
		it "must be 4 bytes long" do 
			frame.pack(error)
			expect(frame.length).to be == 4
			
			frame.length = 3
			
			expect do
				frame.read_payload(stream)
			end.to raise_exception(Protocol::HTTP2::FrameSizeError)
		end
	end
end
