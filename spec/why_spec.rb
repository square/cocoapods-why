# frozen_string_literal: true

require 'spec_helper'

describe Pod::Command::Why do
  it 'finds all dependency paths between two pods' do
    paths = run(%w[A G])
    expect(paths.length).to eq 2
    expect(paths[0]).to eq %w[A B D G]
    expect(paths[1]).to eq %w[A B E G]
  end

  it 'finds no dependency paths between two pods if there are none' do
    expect { run(%w[A Z]) }.to raise_error(CLAide::Help)
  end

  it 'finds all reverse dependencies' do
    deps = run(['G'])
    expect(deps).to eq %w[A B D E]
  end

  it 'finds no reverse dependencies if the pod does not exist' do
    expect { run(['Z']) }.to raise_error(CLAide::Help)
  end

  private

  def run(args = [])
    Pod::Command::Why.new(CLAide::ARGV.new(@args + args)).run
    YAML.safe_load(File.read(@tempfile.path))
  end
end
