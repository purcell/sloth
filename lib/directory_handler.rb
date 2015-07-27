require_relative 'mime_types'
require 'cgi'

class DirectoryHandler

  def initialize(base_dir)
    @base_dir = base_dir
  end

  def handle(method, path)
    return [405, nil] if method != :get
    return [404, nil] if path.split("/").any? { |part| part == ".." }
    filepath = File.join(@base_dir, path)
    return [404, nil] if !File.exists?(filepath)
    if File.directory?(filepath)
      index_file = File.join(filepath, "index.html")
      if File.exists?(index_file)
        filepath = index_file
      else
        return [404, nil]
      end
    end
    headers = {
      "Content-Type" => MimeTypes.from_filename(filepath),
      "Content-Length" => File.size(filepath),
      "Last-Modified" => CGI::rfc1123_date(File.stat(filepath).mtime)
    }
    [200, File.open(filepath), headers]
  end
end
