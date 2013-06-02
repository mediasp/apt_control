# -*- coding: utf-8 -*-
require 'inifile'
require 'listen'
require 'logger'

module AptControl

  require 'apt_control/exec'
  require 'apt_control/notify'
  require 'apt_control/control_file'
  require 'apt_control/apt_site'
  require 'apt_control/build_archive'
  require 'apt_control/package_states'
  require 'apt_control/includer'

  class Version
    include Comparable

    attr_reader :major, :minor, :bugfix, :debian

    def self.parse(string)
      match = /([0-9]+)(?:\.([0-9]+))?(?:\.([0-9]+))?(?:-(.+))?/.match(string)
      match && new(*(1..4).map { |i| match[i] }) or raise "could not parse #{string}"
    end

    def initialize(major, minor, bugfix, debian)
      @major = major && major.to_i
      @minor = minor && minor.to_i
      @bugfix = bugfix && bugfix.to_i
      @debian = debian
    end

    def to_a
      [@major, @minor, @bugfix, @debian]
    end

    def <=>(rhs)
      self.to_a.compact <=> rhs.to_a.compact
    end

    def ==(rhs)
      self.to_a == rhs.to_a
    end

    def =~(rhs)
      self.to_a[0...3] == rhs.to_a[0...3]
    end

    # = operator
    # returns true if this version satisfies the given rule and version spec,
    # where all parts of the version given match our parts.  Not commutative,
    # as  1.3.1.4 satisfies 1.3, but 1.3 does not satisfy 1.3.1.4
    def satisfies_exactly(rhs)
      rhs.to_a.compact.zip(self.to_a).each do |rhs_part, lhs_part|
        return false unless rhs_part == lhs_part
      end
      return true
    end

    # >= operator
    # returns true if this version is greater than or equal to the given version
    def satisfies_loosely(rhs)
      return true if satisfies_exactly(rhs)
      return true if (self.to_a.compact <=> rhs.to_a.compact) >= 0
      return false
    end

    # ~> operator
    def satisfies_pessimisticly(rhs)

      return false unless self.to_a[0...2] == rhs.to_a[0...2]

      lhs_half = self.to_a[2..-1]
      rhs_half = rhs.to_a[2..-1]

      (lhs_half.compact <=> rhs_half.compact) >= 0
    end

    def to_s
      [
        "#{major}.#{minor}",
        bugfix && ".#{bugfix}",
        debian && "-#{debian}"
      ].compact.join
    end
  end
end
