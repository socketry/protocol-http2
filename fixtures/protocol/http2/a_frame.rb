# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/framer'

module Protocol
	module HTTP2
		AFrame = Sus::Shared("a frame") do
			let(:pipe) {Socket.pair(:UNIX, :STREAM)}
			let(:remote) {pipe[0]}
			let(:stream) {pipe[1]}
			
			let(:framer) {Protocol::HTTP2::Framer.new(stream, {subject::TYPE => subject})}
			
			let(:frame) {subject.new}
			
			it "is a valid frame type" do
				expect(frame).to be(:valid_type?)
			end
			
			it "can write the frame" do
				frame.write(remote)
				expect(framer.read_frame).to be == frame
			end
		end
	end
end
