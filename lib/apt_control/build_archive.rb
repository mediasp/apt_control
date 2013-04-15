module AptControl

  # represents a directory containing output from lots of dpkg builds
  class BuildArchive

    attr_reader :packages
    attr_reader :dir

    def initialize(dir)
      @dir = File.expand_path(dir)
      parse!
    end

    # get a list of all versions for a particular package
    def [](name)
      package = packages.find {|p| p.name == name }
      package && package.versions
    end

    # return absolute path to a changes file for a particular package and version
    def changes_fname(package_name, version)
      fname = Dir.chdir(@dir) do
        parsed_changes = Dir["#{package_name}_#{version}_*.changes"].find { |fname|
          parse_changes_fname(fname)
        }
      end

      fname && File.expand_path(File.join(@dir, fname))
    end

    def parse!
      Dir.chdir(@dir) do
        parsed_changes = Dir['*.changes'].map { |fname|
          begin ; parse_changes_fname(fname) ; rescue => e; $stderr.puts(e) ; end
        }.compact

        package_names = parsed_changes.map(&:first).sort.uniq
        @packages = package_names.map do |name|
          versions = parsed_changes.select {|n, v | name == n }.
            map(&:last).
            map {|s| begin ; Version.parse(s) ; rescue => e ; $stderr.puts(e) ; end }.
            compact
          Package.new(name, versions)
        end
      end
    end

    def parse_changes_fname(fname)
      name, version = fname.split('_')[0...2]
      raise "bad changes filename #{fname}" unless name and version
      [name, version]
    end

    # watch the build directory, adding new packages and versions to the
    # in-memory list as it sees them.  Yields to the given block with the
    # package and the new version
    def watch(&block)
      Listen.to(@dir, :filter => /\.changes$/) do |modified, added, removed|
        added.each do |fname|
          begin
            fname = File.basename(fname)
            name, version_string = parse_changes_fname(fname)
            version = Version.parse(version_string)

            package = @packages.find {|p| p.name == name }
            if package.nil?
              @packages << package = Package.new(name, [version])
            else
              package.add_version(version)
            end

            yield(package, version)
          rescue => e
            $stderr.puts("Could not parse changes filename #{fname}: #{e}")
            $stderr.puts(e.backtrace)
            next
          end
        end
      end
    end

    class Package

      attr_reader :name

      def initialize(name, versions)
        @name = name
        @versions = versions
      end

      def add_version(version)
        @versions << version
      end

      def versions
        @versions.sort
      end

      def changes_fname(version) ; end

    end
  end
end
