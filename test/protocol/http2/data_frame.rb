# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/data_frame'
require 'frame_examples'

describe Protocol::HTTP2::DataFrame do
	let(:frame) {subject.new}
	
	it_behaves_like FrameExamples do
		def before
			frame.pack "Hello World!"
			
			super
		end
	end
	
	with "wire representation" do
		let(:stream) {StringIO.new}
		
		let(:payload) {'Hello World!'}
		
		let(:data) do
			[0, 12, 0x0, 0x1, 0x1].pack('CnCCNC*') + payload
		end
		
		it "should write frame to buffer" do
			frame.set_flags(Protocol::HTTP2::END_STREAM)
			frame.stream_id = 1
			frame.payload = payload
			frame.length = payload.bytesize
			
			frame.write(stream)
			
			expect(stream.string).to be == data
		end
		
		it "should read frame from buffer" do
			stream.write(data)
			stream.seek(0)
			
			frame.read(stream)
			
			expect(frame.length).to be == payload.bytesize
			expect(frame.flags).to be == Protocol::HTTP2::END_STREAM
			expect(frame.stream_id).to be == 1
			expect(frame.payload).to be == payload
		end
	end
	
	with '#pack' do
		it "adds appropriate padding" do
			frame.pack "Hello World!", padding_size: 4
			
			expect(frame.length).to be == 16
			expect(frame.payload[0].ord).to be == 4
			expect(frame.unpack).to be == "Hello World!"
			
			stream = StringIO.new
			frame.write(stream)
			
			expect(stream.string.bytesize).to be == 25
			stream.rewind
			
			frame2 = subject.new
			frame2.read(stream)
			
			expect(frame2.unpack).to be == "Hello World!"
			expect(frame2).to be(:padded?)
		end
		
		it "can pack end frame" do
			frame.pack(nil)
			
			expect(frame.length).to be == 0
			expect(frame.flags).to be == Protocol::HTTP2::END_STREAM
			expect(frame).to be(:end_stream?)
		end
	end
	
	with '#unpack' do
		it "removes padding" do
			frame.pack "Hello World!"
			
			expect(frame.unpack).to be == "Hello World!"
		end
	end
	
	with '#inspect' do
		it "can generate a string representation" do
			expect(frame.inspect).to be =~ /Protocol::HTTP2::DataFrame stream_id=0 flags=0 0b/
		end
	end
end
