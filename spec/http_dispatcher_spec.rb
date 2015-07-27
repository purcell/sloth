require_relative "../lib/http_dispatcher"
require 'stringio'
require 'zlib'

RSpec.describe HTTPDispatcher do

  let(:handler) { double("handler") }
  let(:path) { "path" + rand(1..1000).to_s }
  let(:method) { "GET" }
  let(:request) { with_header(["#{method} /#{path} HTTP/1.0"]) }
  let(:access_log) { StringIO.new }
  let(:error_log) { StringIO.new }
  let(:response_stream) { StringIO.new }
  let(:request_stream) { StringIO.new(request) }
  let(:handler_response) { StringIO.new("response" + rand.to_s) }
  subject(:dispatcher) { HTTPDispatcher.new(handler, access_log, error_log) }

  TEXT_PLAIN_HEADERS = { "Content-Type" => 'text/plain' }

  def with_header(headers, body="")
    (headers + ["", body]).join("\r\n")
  end

  context "with a valid request" do
    before do
      expect(handler).to receive(:handle).with(:get, path).and_return([200, handler_response, TEXT_PLAIN_HEADERS])
      dispatcher.run(request_stream, response_stream)
    end

    it "calls the handler and writes its stream contents to the response" do
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 200 OK",
                                                        "Content-Type: text/plain"],
                                                       handler_response.string))
    end

    it "logs the request" do
      expect(access_log.string).to eq("GET #{path} 200\n")
    end
  end

  context "with a different request method" do
    let(:method) { "POST" }
    it "calls the handler and writes its stream contents to the response" do
      expect(handler).to receive(:handle).with(:post, path).and_return([200, handler_response, TEXT_PLAIN_HEADERS])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 200 OK",
                                                        "Content-Type: text/plain"],
                                                       handler_response.string))
    end
  end

  context "with no response body from the handler" do
    it "just responds with the status code" do
      expect(handler).to receive(:handle).with(:get, path).and_return([200, nil])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 200 OK"]))
    end
  end

  context "with a non-200 response code from the handler" do
    it "responds with that status code" do
      expect(handler).to receive(:handle).with(:get, path).and_return([404, nil])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 404 Not Found"]))
    end
  end

  context "with a string response body from the handler" do
    it "responds with that body" do
      expect(handler).to receive(:handle).with(:get, path).and_return([200, "Some response", TEXT_PLAIN_HEADERS])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 200 OK",
                                                        "Content-Type: text/plain"],
                                                       "Some response"))
    end
  end

  context "when the handler explodes" do
    it "returns a 500 status code" do
      expect(handler).to receive(:handle).with(:get, path).and_raise(StandardError)
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 500 Internal Server Error",
                                                        "Content-Type: text/plain"],
                                                       "Internal Server Error"))
    end
  end

  context "with nonsense request input" do
    let(:request) { "BLAH BLAH\n" }
    it "returns a 400 status code" do
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 400 Bad Request"]))
    end
  end

  context "with extra request headers" do
    let(:request) do
      with_header(["GET /foo HTTP/1.0",
                   "Accept-Encoding: text/plain",
                   "X-Some-Other: blah"])
    end

    it "ignores the headers" do
      expect(handler).to receive(:handle).with(:get, "foo").and_return([200, "Some response", TEXT_PLAIN_HEADERS])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 200 OK",
                                                        "Content-Type: text/plain"],
                                                       "Some response"))
    end
  end

  context "with no blank line after request" do
    let(:request) do
      ["GET /foo HTTP/1.0", "Accept-Encoding: text/plain"].join("\r\n")
    end
    it "rejects the request" do
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 400 Bad Request"]))
    end
  end

  context "with an IO error reading the request" do
    it "rejects the request" do
      request_stream = double("request stream")
      allow(request_stream).to receive(:readline).and_raise(IOError)
      allow(request_stream).to receive(:read).and_raise(IOError)
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 400 Bad Request"]))
    end
  end

  context "when the handler returns extra headers" do
    it "writes those headers to the response" do
      expect(handler).to receive(:handle).with(:get, path).and_return([200, "Some response", { "X-Magic" => "Abracadabra" }])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 200 OK",
                                                        "X-Magic: Abracadabra"],
                                                       "Some response"))
    end
  end

  context "when the client accepts gzip encoding" do
    let(:request) { with_header([
                                  "#{method} /#{path} HTTP/1.0",
                                  "Accept-Encoding: gzip"
                                ]) }

    it "compresses text/* responses" do
      uncompressed_response = ("Some response" * 100).force_encoding(Encoding::ASCII_8BIT)
      compressed_response = Zlib.deflate(uncompressed_response)
      expect(handler).to receive(:handle).with(:get, path).and_return(
                           [200, uncompressed_response, { "Content-Type" => "text/blahblah" }])
      dispatcher.run(request_stream, response_stream)
      expect(response_stream.string).to eq(with_header(["HTTP/1.0 200 OK",
                                                        "Content-Type: text/blahblah",
                                                        "Content-Encoding: gzip",
                                                        "Content-Length: #{compressed_response.bytesize}"],
                                                       compressed_response))
    end
  end
end
