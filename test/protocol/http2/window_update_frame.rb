# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/window_update_frame'
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
end
