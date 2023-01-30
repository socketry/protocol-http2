# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/priority_frame'
require 'frame_examples'

describe Protocol::HTTP2::PriorityFrame do
	let(:priority) {Protocol::HTTP2::Priority.new(true, 42, 7)}
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.pack priority
			
			super
		end
	end
	
	with '#pack' do
		it "packs priority" do
			frame.pack priority
			
			expect(frame.length).to be == 5
		end
	end
	
	with '#unpack' do
		it "unpacks priority" do
			frame.pack priority
			
			expect(frame.unpack).to be == priority
		end
	end
end
