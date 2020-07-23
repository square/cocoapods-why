# frozen_string_literal: true

require 'spec_helper'

CACHE = "#{__dir__}/cache.yaml"
CACHE_DFS = "#{__dir__}/cache_dfs.yaml"

describe Pod::Command::Why do
  it 'finds all dependency paths between two pods' do
    paths = run(%w[A G])
    expect(paths.length).to eq 2
    expect(paths[0]).to eq %w[A B D G]
    expect(paths[1]).to eq %w[A B E G]
  end

  it 'does not use simple DFS to find dependency paths between two pods' do
    paths = run(%w[A D], ["--cache=#{CACHE_DFS}"])
    expect(paths.length).to eq 3
    expect(paths[0]).to eq %w[A B C D]
    expect(paths[1]).to eq %w[A B D]
    expect(paths[2]).to eq %w[A C D]
  end

  it 'finds no dependency paths between two pods if there are none' do
    expect { run(%w[A Z]) }.to raise_error(CLAide::Help)
  end

  it 'finds all dependencies' do
    deps = run(['B'])
    expect(deps).to eq %w[D E G H]
  end

  it 'finds no dependencies if the pod does not exist' do
    expect { run(['Z']) }.to raise_error(CLAide::Help)
  end

  it 'finds all reverse dependencies' do
    deps = run(['G', '--reverse'])
    expect(deps).to eq %w[A B D E]
  end

  it 'finds no reverse dependencies if the pod does not exist' do
    expect { run(['Z', '--reverse']) }.to raise_error(CLAide::Help)
  end

  private

  def run(args = [], cache_arg = ["--cache=#{CACHE}"])
    Pod::Command::Why.new(CLAide::ARGV.new(@args + cache_arg + args)).run
    YAML.safe_load(File.read(@tempfile.path))
  end
end
