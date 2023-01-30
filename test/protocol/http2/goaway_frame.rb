# Copyright, 2018, by Samuel G. D. Williams. <http: //www.codeotaku.com>
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

require 'protocol/http2/goaway_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::GoawayFrame do
	let(:data) {"Hikikomori desu!"}
	
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack 1, 2, data
		end
	end
	
	describe '#pack' do
		it "packs data" do
			subject.pack 3, 2, data
			
			expect(subject.length).to be == 8+data.bytesize
		end
	end
	
	describe '#unpack' do
		it "unpacks data" do
			subject.pack 3, 2, data
			
			expect(subject.unpack).to be == [3, 2, data]
		end
	end
end
