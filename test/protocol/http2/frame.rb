# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/frame'

describe Protocol::HTTP2::Frame do
	let(:frame) {subject.new(0, 0, 0)}
	
	with '#read_payload' do
		it "can read a frame with payload and matching length" do
			buffer = StringIO.new("Hello World!")
			
			frame.length = 12
			frame.read_payload(buffer)
			
			expect(frame.payload).to be == "Hello World!"
		end
	end
	
	with '#write_payload' do
		it "can write a frame with payload and matching length" do
			buffer = StringIO.new
			
			frame.payload = "Hello World!"
			frame.length = 12
			frame.write_payload(buffer)
			
			expect(buffer.string).to be == "Hello World!"
		end
	end
	
	it "isn't a valid frame type" do
		expect(frame).not.to be(:valid_type?)
	end
	
	it "cannot pack frame with payload larger than maximum frame size" do
		expect do
			frame.pack("Hello World!", maximum_size: 6)
		end.to raise_exception(
			Protocol::HTTP2::ProtocolError,
			message: be =~ /Frame length bigger than maximum allowed/
		)
	end
	
	it "cannot write a frame with missing payload and non-zero length" do
		expect do
			frame.length = 1
			frame.write(StringIO.new)
		end.to raise_exception(
			Protocol::HTTP2::ProtocolError,
			message: be =~ /Invalid frame length/
		)
	end
	
	it "cannot write frame with payload and mismatched length" do
		expect do
			frame.payload = "Hello World!"
			frame.length = 1
			frame.write(StringIO.new)
		end.to raise_exception(
			Protocol::HTTP2::ProtocolError,
			message: be =~ /Invalid payload size/
		)
	end
	
	with 'a connection' do
		let(:connection) {Protocol::HTTP2::Connection.new(nil, 0)}
		
		it "can apply a frame to the connection" do
			expect(connection).to receive(:receive_frame)
			frame.apply(connection)
		end
	end
	
	with '#inspect' do
		it "can generate a string representation" do
			expect(frame.inspect).to be =~ /Protocol::HTTP2::Frame stream_id=0/
		end
	end
end
