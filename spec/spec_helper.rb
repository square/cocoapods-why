# frozen_string_literal: true

require_relative '../lib/pod/command/why'

require 'yaml'

CACHE = "#{__dir__}/cache.yaml"

RSpec.configure do |config|
  config.before(:each) do
    @tempfile = Tempfile.new('why')
    @args = ["--to-yaml=#{@tempfile.path}", "--cache=#{CACHE}", '--silent']
  end

  config.after(:each) do
    @tempfile.unlink
  end
end
