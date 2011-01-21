require "fpm/namespace"
require "fpm/source"
require "fileutils"
require "json"

class FPM::Source::Npm < FPM::Source
  # Get the source if we need to download it
  def get_source(builddir)
    @npm = @paths.first

    # Set up the install root
    Dir.mkdir(builddir) if !File.exists?(builddir)
    File.open("#{builddir}/.npmrc", "w") do |file|
      file.puts "root = #{builddir}/usr/lib/node"
      file.puts "binroot = #{builddir}/usr/lib/node/bin"
      file.puts "manroot = #{builddir}/usr/share/man"
    end

    if !File.exists(@npm)
      system("env - PATH=$PATH HOME=#{builddir} npm install #{self.name} #{self..version or ""}")
    end

    File.delete("#{builddir}/.npmrc")

    @paths = [ builddir ]
  end # def get_source

  # Get metadata from the source
  def get_metadata
    # set self[:...] values
    # :name
    # :maintainer
    # :url
    # :category
    # :dependencies
   
    # Find the version we just installed.
    package_path = Dir.glob("#{builddir}/usr/lib/node/.npm/#{self.name}/*")\
      .reject { |path| File.symlink?(path) }\
      .first

    package = JSON.parse(File.new("#{package_path}/package/package.json").read())

    self[:name] = "nodejs-#{package["name"]}"
    self[:maintainer] = (package["author"] or "no author known")
    self[:category] = 'Languages/Development/JavaScript'

    # TODO(sissel): Ideally we want to say any version with the same 'release' number, like
    # So we'll specify deps of {v}-1 <= x <= {v}-999999....
    self[:dependencies] = Dir.glob("#{package_path}/dependson/*@*") \
      .collect { |p| PACKAGEPREFIX + File.basename(p) } \
      .collect { |p| n,v = p.split("@"); 
        ["#{n} (>= #{v}-1)", "#{n} (<= #{v}-99999999999999)"] 
    }.flatten
  end # def get_metadata

  def make_tarball!(tar_path, builddir)
    tmpdir = "#{tar_path}.dir"

    # TODO(sissel): Only include files with this particular package
    # TODO(sissel): Also include the 'active' symlink?
    tar(tar_path, ".", tmpdir)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end

end # class FPM::Source::Gem
