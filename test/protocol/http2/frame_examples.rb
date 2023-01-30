# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/framer'

RSpec.shared_examples Protocol::HTTP2::Frame do
	let(:stream) {StringIO.new}
	
	it "can write frame" do
		subject.write(stream)
		
		expect(stream.string).to_not be_empty
	end
	
	let(:framer) {Protocol::HTTP2::Framer.new(stream, {described_class::TYPE => described_class})}
	
	it "can read frame using framer" do
		subject.write(stream)
		stream.seek(0)
		
		expect(framer.read_frame).to be == subject
	end
end
