# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/framer'

FrameExamples = Sus::Shared("a frame") do
	let(:stream) {StringIO.new}
	let(:frame) {subject.new}
	
	it "is a valid frame type" do
		expect(frame).to be(:valid_type?)
	end
	
	it "can write the frame" do
		frame.write(stream)
		
		expect(stream.string).not.to be(:empty?)
	end
	
	let(:framer) {Protocol::HTTP2::Framer.new(stream, {subject::TYPE => subject})}
	
	it "can read the frame using framer" do
		frame.write(stream)
		stream.seek(0)
		
		expect(framer.read_frame).to be == frame
	end
end
