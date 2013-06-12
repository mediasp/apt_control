require 'test/helpers'

describe 'AptControl::Bot::ArgHelpers' do
  include AptControl::Bot::ArgHelpers

  it 'equates empty or whatspace to no args' do
    assert_equal [], split_args('')
    assert_equal [], split_args(' ')
    assert_equal [], split_args('     ')
  end

  it 'can cope with a single arg with surrounding whitespace' do
    assert_equal ['foo'], split_args('foo')
    assert_equal ['foo'], split_args('  foo  ')
    assert_equal ['foo'], split_args(' foo')
    assert_equal ['foo'], split_args('foo   ')
  end

  it 'can split up more than one arg with surrounding whitespace' do
    assert_equal ['foo', 'bar'], split_args('foo bar')
    assert_equal ['foo', 'bar'], split_args('foo   bar')
    assert_equal ['foo', 'bar'], split_args('   foo   bar')
    assert_equal ['foo', 'bar'], split_args('   foo   bar   ')
  end

  it 'can treat multiple args as one with quotes' do
    assert_equal ['foo', 'bar', 'baz'], split_args('foo bar baz')
    assert_equal ['foo', 'bar baz', 'foo'], split_args('foo "bar baz" foo')
    assert_equal ['foo', 'bar baz', 'foo'], split_args("foo 'bar baz' foo")
  end

  it 'preserves whitespace within quotes' do
    assert_equal ['foo bar'], split_args("'foo bar'")
    assert_equal ['  foo bar  '], split_args("'  foo bar  '")
    assert_equal ['  foo   bar  '], split_args("'  foo   bar  '")
  end

  it 'does not split on some special characters' do
    assert_equal ['foo_bar'], split_args('foo_bar')
    assert_equal ['foo+bar'], split_args('foo+bar')
    assert_equal ['foo-bar'], split_args('foo-bar')
  end
end
