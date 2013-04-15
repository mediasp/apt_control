require 'minitest/autorun'
require 'minitest/spec'
require 'apt_control'

describe 'AptControl::Version' do

  def assert_satisfies_exactly(lhs, rhs)
    lhs = AptControl::Version.parse(lhs)
    rhs = AptControl::Version.parse(rhs)

    assert lhs.satisfies_exactly(rhs), "#{lhs} not = #{rhs}"
  end

  def refute_satisfies_exactly(lhs, rhs)
    lhs = AptControl::Version.parse(lhs)
    rhs = AptControl::Version.parse(rhs)

    refute lhs.satisfies_exactly(rhs), "#{lhs} = #{rhs}"
  end

  def assert_satisfies_loosely(lhs, rhs)
    lhs = AptControl::Version.parse(lhs)
    rhs = AptControl::Version.parse(rhs)

    assert lhs.satisfies_loosely(rhs), "#{lhs} not >= #{rhs}"
  end

  def refute_satisfies_loosely(lhs, rhs)
    lhs = AptControl::Version.parse(lhs)
    rhs = AptControl::Version.parse(rhs)

    refute lhs.satisfies_loosely(rhs), "#{lhs} >= #{rhs}"
  end

  def assert_satisfies_pessimisticly(lhs, rhs)
    lhs = AptControl::Version.parse(lhs)
    rhs = AptControl::Version.parse(rhs)

    assert lhs.satisfies_pessimisticly(rhs), "#{lhs} not ~> #{rhs}"
  end

  def refute_satisfies_pessimisticly(lhs, rhs)
    lhs = AptControl::Version.parse(lhs)
    rhs = AptControl::Version.parse(rhs)

    refute lhs.satisfies_pessimisticly(rhs), "#{lhs} ~> #{rhs}"
  end

  it '#satisfies_exactly' do
    assert_satisfies_exactly '1.1',     '1.1'
    assert_satisfies_exactly '1.1.0',   '1.1'
    assert_satisfies_exactly '1.1.0-1', '1.1'
    assert_satisfies_exactly '1.1.0-a', '1.1'
    assert_satisfies_exactly '1.1.1',   '1.1'
    assert_satisfies_exactly '1.1.1.1',   '1.1'
    assert_satisfies_exactly '0.1.1.1',   '0.1'

    refute_satisfies_exactly '1.1',     '1.1.1'
    refute_satisfies_exactly '1.1',     '1.1.0'
    refute_satisfies_exactly '1.1',     '1.1.0'
    refute_satisfies_exactly '1.1',     '1.1.0-1'
  end

  it '#satisfies_loosely' do
    assert_satisfies_loosely '1.0', '1.0'
    assert_satisfies_loosely '1.1', '1.0'
    assert_satisfies_loosely '1.1.9', '1.0'
    assert_satisfies_loosely '1.1.9-catdogversion', '1.0'
    assert_satisfies_loosely '2.0', '1.0'
    assert_satisfies_loosely '2.9.20-2323', '1.0'

    assert_satisfies_loosely '1.5.6', '1.5.6'
    assert_satisfies_loosely '1.5.6-0', '1.5.6'
    assert_satisfies_loosely '1.5.7', '1.5.6'
    assert_satisfies_loosely '1.7.0', '1.5.6'
    assert_satisfies_loosely '2.0.0', '1.5.6'

    refute_satisfies_loosely '1.5.5-100', '1.5.6-0'
    refute_satisfies_loosely '1.5.6', '1.5.6-0'
    refute_satisfies_loosely '1', '2'
    refute_satisfies_loosely '1.9', '2'
    refute_satisfies_loosely '1.9.4', '1.9.5'
    refute_satisfies_loosely '1.9.5-5', '1.9.5-6'
  end

  it '#satisfies_pessimisticly' do
    assert_satisfies_pessimisticly '1.5.6', '1.5.6'
    assert_satisfies_pessimisticly '1.5.6-1', '1.5.6'
    assert_satisfies_pessimisticly '1.5.6-3', '1.5.6'
    assert_satisfies_pessimisticly '1.5.7', '1.5.6'
    assert_satisfies_pessimisticly '1.5.20-cats', '1.5.6'

    assert_satisfies_pessimisticly '1.5.6-1', '1.5.6-1'
    assert_satisfies_pessimisticly '1.5.6-2', '1.5.6-1'
    assert_satisfies_pessimisticly '1.5.20-1', '1.5.6-1'
    assert_satisfies_pessimisticly '1.5.20-1', '1.5.6-20'

    refute_satisfies_pessimisticly '1.6.0', '1.5.6'
    refute_satisfies_pessimisticly '1.6.0', '1.6.1'
    refute_satisfies_pessimisticly '1.5.6', '1.5.6-5'
    refute_satisfies_pessimisticly '1.5.6-1', '1.5.6-5'
    refute_satisfies_pessimisticly '2.0.0', '1.5.6'
  end

end
