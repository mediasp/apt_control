module AptControl
  # represents the reprepro apt site that we query and include packages in to
  class AptSite
    include Exec::Helpers

    def initialize(apt_site_dir, logger)
      @apt_site_dir = apt_site_dir
      @logger = logger
    end

    def reprepro_cmd
      "reprepro -b #{@apt_site_dir}"
    end

    # query the apt site for which version of a package is installed for a
    # particular distribution
    def included_version(distribution_name, package_name)
      command = "#{reprepro_cmd} -Tdsc list #{distribution_name} #{package_name}"
      output = exec(command, :name => 'reprepro')
      version_string = output.split(' ').last
      version_string && Version.parse(version_string)
    end

    # include a particular version in to a distribution.  Will likely fail for a
    # myriad number of reasons, so spits out error messages to sdterr
    def include!(distribution_name, changes_fname)
      command = "#{reprepro_cmd} --ignore=wrongdistribution include #{distribution_name} #{changes_fname}"
      begin
        exec(command, :name => 'reprepro')
        true
      rescue Exec::UnexpectedExitStatus => e
        @logger.error("Error executing: #{e.command}")
        @logger.error(e.stderr)
        false
      end
    end
  end
end
