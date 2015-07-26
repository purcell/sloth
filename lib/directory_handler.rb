class DirectoryHandler
  class NotFound < StandardError
  end
  class MethodNotAllowed < StandardError
  end

  def initialize(base_dir)
    @base_dir = base_dir
  end

  def handle(method, path)
    raise MethodNotAllowed unless method == :get
    raise NotFound if path.split("/").any? { |part| part == ".." }
    filepath = File.join(@base_dir, path)
    raise NotFound unless File.exists?(filepath)
    File.open(filepath)
  end
end
