require_relative "../lib/directory_handler"


RSpec.describe DirectoryHandler do

  let(:base_dir) { File.join(File.dirname(__FILE__), "test-data") }
  let(:handler) { DirectoryHandler.new(base_dir) }

  context "when requesting a file which exists" do
    it "returns a stream to the file contents" do
      status, stream, headers = handler.handle(:get, "example.txt")
      expect(status).to eq(200)
      expect(headers).to eq({
                              "Content-Type" => "text/plain",
                              "Content-Length" => 30
                            })
      expect(stream.read).to eq(File.read(File.join(base_dir, "example.txt")))
    end
  end

  context "when requesting a file with an unknown mime type exists" do
    it "returns a default mime type" do
      status, stream, headers = handler.handle(:get, "blabla")
      expect(status).to eq(200)
      expect(headers).to eq({
                              "Content-Type" => "binary/octet-stream",
                              "Content-Length" => 6
                            })
      expect(stream.read).to eq(File.read(File.join(base_dir, "blabla")))
    end
  end

  context "when requesting invalid files" do
    it "raises an error if files do not exist" do
      expect(handler.handle(:get, "blahahala")).to eq([404, nil])
    end

    it "raises an error if path starts with '..'" do
      expect(handler.handle(:get, "../test-data/example.txt")).to eq([404, nil])
    end

    it "raises an error if path contains '..'" do
      expect(handler.handle(:get, "subdir/../../test-data/example.txt")).to eq([404, nil])
    end
  end

  context "when making non-GET requests" do
    it "raises an error" do
      expect(handler.handle(:post, "example.txt")).to eq([405, nil])
    end
  end

  context "when requesting a directory with no index.html" do
    it "returns a 404" do
      expect(handler.handle(:get, "")).to eq([404, nil])
    end
  end

  context "when requesting a directory with an index.html" do
    it "returns a 200 and that index file" do
      file = File.join(base_dir, "subdir", "index.html")
      status, stream, headers = handler.handle(:get, "subdir")
      expect(status).to eq(200)
      expect(headers).to eq({
                              "Content-Type" => "text/html",
                              "Content-Length" => File.size(file)
                            })
      expect(stream.read).to eq(File.read(file))
    end
  end
end
