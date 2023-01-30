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
end
