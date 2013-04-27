module AptControl::CLI
  class Status < Climate::Command('status')
    include Common
    subcommand_of Root
    description "Dump current state of apt site and build archive"

    opt :machine_readable, "If true, output in a unix-friendly format", :default => false

    def run
      validate_config!

      control_file.distributions.each do |dist|
        puts dist.name unless options[:machine_readable]
        dist.package_rules.each do |rule|
          included = apt_site.included_version(dist.name, rule.package_name)
          available = build_archive[rule.package_name]

          satisfied = included && rule.satisfied_by?(included)
          upgradeable = available && rule.upgradeable?(included, available)

          if options[:machine_readable]
            fields = [
              dist.name,
              rule.package_name,
              "(#{rule.restriction} #{rule.version})",
              "#{upgradeable ? 'U' : '.'}#{satisfied ? 'S' : '.'}",
              "included=#{included || '<none>'}",
              "available=#{available && available.join(', ') || '<none>'} "
            ]
            puts fields.join(' ')
          else
            puts "  #{rule.package_name}"
            puts "    rule       - #{rule.restriction} #{rule.version}"
            puts "    included   - #{included}"
            puts "    available  - #{available && available.join(', ')}"
            puts "    satisfied  - #{satisfied}"
            puts "    upgradeable - #{upgreadable}"
          end
        end
      end
    end
  end
end
