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
    [200, File.open(filepath)]
  end
end
