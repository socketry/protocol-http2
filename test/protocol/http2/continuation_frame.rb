# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "protocol/http2/continuation_frame"
require "protocol/http2/a_frame"

describe Protocol::HTTP2::ContinuationFrame do
	let(:data) {"Hello World!"}
	let(:frame) {subject.new}
	
	it_behaves_like Protocol::HTTP2::AFrame do
		def before
			frame.pack data
			
			super
		end
	end
	
	with "#pack" do
		it "packs data" do
			frame.pack data
			
			expect(frame.length).to be == data.bytesize
		end
		
		it "packs data over multiple continuation frames" do
			frame.pack data, maximum_size: 6
			
			expect(frame.continuation).not.to be_nil
		end
	end
	
	with "#unpack" do
		it "unpacks data" do
			frame.pack data
			
			expect(frame.unpack).to be == data
		end
		
		it "unpacks data over multiple continuations" do
			frame.pack data, maximum_size: 2
			
			expect(frame.unpack).to be == data
		end
	end
	
	with "#apply" do
		let(:connection) {Protocol::HTTP2::Connection.new(nil, 0)}
		
		it "applies the frame to a connection" do
			expect(connection).to receive(:receive_continuation).and_return(true)
			
			frame.pack data
			frame.apply(connection)
		end
	end
	
	with "#inspect" do
		it "can generate a string representation" do
			expect(frame.inspect).to be =~ /stream_id=0 flags=0 length=0/
		end
	end
	
	with "read(limit)" do
		it "reads a single frame" do
			frame.pack data
			
			buffer = StringIO.new
			frame.write(buffer)
			buffer.rewind
			
			new_frame = subject.new
			new_frame.read(buffer, 128, 0)
			expect(new_frame.unpack).to be == data
		end
		
		it "raises if too many continuation frames" do
			frame.pack data, maximum_size: 2
			
			buffer = StringIO.new
			frame.write(buffer)
			buffer.rewind
			
			expect do
				new_frame = subject.new
				new_frame.read(buffer, 128, 1)
			end.to raise_exception(Protocol::HTTP2::ProtocolError, message: be =~ /Too many continuation frames!/)
		end
		
		it "reads multiple continuation frames" do
			frame.pack data, maximum_size: 2
			
			buffer = StringIO.new
			frame.write(buffer)
			buffer.rewind
			
			new_frame = subject.new
			new_frame.read(buffer, 128, 8)
			expect(new_frame.unpack).to be == data
		end
	end
end
