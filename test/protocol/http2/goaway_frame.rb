# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "protocol/http2/goaway_frame"
require "protocol/http2/a_frame"

describe Protocol::HTTP2::GoawayFrame do
	let(:data) {"Hikikomori desu!"}
	let(:frame) {subject.new}
	
	it_behaves_like Protocol::HTTP2::AFrame do
		def before
			frame.pack 1, 2, data
			
			super
		end
	end
	
	it "applies to the connection" do
		frame.pack(0, 0, "")
		
		expect(frame).to be(:connection?)
	end
	
	with "#pack" do
		it "packs data" do
			frame.pack 3, 2, data
			
			expect(frame.length).to be == 8+data.bytesize
		end
	end
	
	with "#unpack" do
		it "unpacks data" do
			frame.pack 3, 2, data
			
			expect(frame.unpack).to be == [3, 2, data]
		end
	end
end
