# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http2/continuation_frame'
require 'protocol/http2/a_frame'

describe Protocol::HTTP2::ContinuationFrame do
	let(:data) {"Hello World!"}
	let(:frame) {subject.new}
	
	it_behaves_like Protocol::HTTP2::AFrame do
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
	
	with '#apply' do
		let(:connection) {Protocol::HTTP2::Connection.new(nil, 0)}
		
		it "applies the frame to a connection" do
			expect(connection).to receive(:receive_continuation).and_return(true)
			
			frame.pack data
			frame.apply(connection)
		end
	end
	
	with '#inspect' do
		it "can generate a string representation" do
			expect(frame.inspect).to be =~ /stream_id=0 flags=0 length=0/
		end
	end
end
