# Copyright, 2018, by Samuel G. D. Williams. <http: //www.codeotaku.com>
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

require 'protocol/http2/data_frame'
require_relative 'frame_examples'

RSpec.describe Protocol::HTTP2::DataFrame do
	it_behaves_like Protocol::HTTP2::Frame do
		before do
			subject.pack "Hello World!"
		end
	end
	
	context 'wire representation' do
		let(:stream) {StringIO.new}
		
		let(:payload) {'Hello World!'}
		
		let(:data) do
			[0, 12, 0x0, 0x1, 0x1].pack('CnCCNC*') + payload
		end
		
		it "should write frame to buffer" do
			subject.set_flags(Protocol::HTTP2::END_STREAM)
			subject.stream_id = 1
			subject.payload = payload
			subject.length = payload.bytesize
			
			subject.write(stream)
			
			expect(stream.string).to be == data
		end
		
		it "should read frame from buffer" do
			stream.write(data)
			stream.seek(0)
			
			subject.read(stream)
			
			expect(subject.length).to be == payload.bytesize
			expect(subject.flags).to be == Protocol::HTTP2::END_STREAM
			expect(subject.stream_id).to be == 1
			expect(subject.payload).to be == payload
		end
	end
	
	describe '#pack' do
		it "adds appropriate padding" do
			subject.pack "Hello World!", padding_size: 4
			
			expect(subject.length).to be == 16
			expect(subject.payload[0].ord).to be == 4
		end
	end
	
	describe '#unpack' do
		it "removes padding" do
			subject.pack "Hello World!"
			
			expect(subject.unpack).to be == "Hello World!"
		end
	end
end
