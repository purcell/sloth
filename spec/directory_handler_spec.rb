require_relative "../lib/directory_handler"


RSpec.describe DirectoryHandler do

  let(:base_dir) { File.join(File.dirname(__FILE__), "test-data") }
  let(:handler) { DirectoryHandler.new(base_dir) }

  context "when requesting a file which exists" do
    it "returns a stream to the file contents" do
      stream = handler.handle(:get, "example.txt")
      expect(stream.read).to eq(File.read(File.join(base_dir, "example.txt")))
    end
  end

  context "when requesting invalid files" do
    it "raises an error if files do not exist" do
      expect { handler.handle(:get, "blahahala") }.to raise_error(DirectoryHandler::NotFound)
    end

    it "raises an error if path starts with '..'" do
      expect { handler.handle(:get, "../test-data/example.txt") }.to raise_error(DirectoryHandler::NotFound)
    end

    it "raises an error if path contains '..'" do
      expect { handler.handle(:get, "subdir/../../test-data/example.txt") }.to raise_error(DirectoryHandler::NotFound)
    end
  end

  context "when making non-GET requests" do
    it "raises an error" do
      expect { handler.handle(:post, "example.txt") }.to raise_error(DirectoryHandler::MethodNotAllowed)
    end
  end
end
