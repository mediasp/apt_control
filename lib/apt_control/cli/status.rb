module AptControl::CLI
  class Status < Climate::Command('status')
    include Common
    subcommand_of Root
    description "Dump current state of apt site and build archive"

    opt :machine_readable, "If true, output in a unix-friendly format", :default => false

    def run
      validate_config!

      if options[:machine_readable]
        package_states.each do |state|
          fields = [
            state.dist.name,
            state.package_name,
            "(#{state.rule.restriction} #{state.rule.version})",
            "#{state.upgradeable? ? 'U' : '.'}#{state.satisfied? ? 'S' : '.'}",
            "included=#{state.included || '<none>'}",
            "available=#{state.available? ? state.available.join(', ') : '<none>'} "
          ]
          puts fields.join(' ')
        end
      else
        last_dist = nil
        package_states.each do |state|
          puts state.dist.name if last_dist != state.dist
          last_dist = state.dist
          puts "  #{state.package_name}"
          puts "    rule       - #{state.rule.restriction} #{state.rule.version}"
          puts "    included   - #{state.included}"
          puts "    available  - #{state.available.join(', ')}"
          puts "    satisfied  - #{state.satisfied?}"
          puts "    upgradeable - #{state.upgradeable?}"
        end
      end
    end
  end
end
