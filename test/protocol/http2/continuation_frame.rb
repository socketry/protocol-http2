# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/continuation_frame'
require 'frame_examples'

describe Protocol::HTTP2::ContinuationFrame do
	let(:data) {"Hello World!"}
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
			
			expect(frame.length).to be == data.bytesize
		end
		
		it "packs data over multiple continuation frames" do
			frame.pack data, maximum_size: 6
			
			expect(frame.continuation).not.to be_nil
		end
	end
	
	with '#unpack' do
		it "unpacks data" do
			frame.pack data
			
			expect(frame.unpack).to be == data
		end
		
		it "unpacks data over multiple continuations" do
			frame.pack data, maximum_size: 2
			
			expect(frame.unpack).to be == data
		end
	end
end
