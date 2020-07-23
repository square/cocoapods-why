# Introduction

This plugin for CocoaPods helps understand the dependencies between two pods. It is intended for projects with a large number of dependencies.

The plugin's output can be saved to YAML format for easy parsing by other tools (e.g. a CocoaPods GUI) or to GraphViz format for visualization.

# Installation

Add this line to your application's Gemfile:

    gem 'cocoapods-why'

And then run:

    $ bundle

Or, install it system-wide with:

    $ gem build cocoapods-why.gemspec
	$ gem install cocoapods-why-1.0.0.gem

Or, in a single command:

    $ bundle exec rake install

# Usage

The plugin adds a `why` command to CocoaPods. You can get help on its parameters with:

    $ pod why --help

## All Paths Between Pods

The most common usage of the `why` command is to show all paths between two pods Foo and Bar:

    $ pod why Foo Bar

This is helpful for understanding why a particular pod has a transitive dependency on some other pod (possibly one you do not want). By default, it simply lists the paths, but it can also produce a graph of them.

## All Paths To A Pod

The `why` command can also show all pods that depend on some other pod, either directly or transitively.

    $ pod why Foo

This is helpful for finding the set of pods that consume a particular pod and will have to be rebuilt (or could break) if it changes. By default, the command lists all of the pods, but it can also produce a graph of them.

# Graphing

The `why` command can produce a graph of its output with the `--to-dot` argument, which takes a file name as a parameter. The output file will be in [DOT format](https://en.wikipedia.org/wiki/DOT_\(graph_description_language\)), which can be visualized with a DOT processor. For example, you can generate a PDF from a DOT file with this GraphViz command:

    $ dot -Tpdf dependencies.dot > dependencies.pdf

# Caching

Finding pods in the CocoaPods project can take a long time when there are many dependencies. To speed things up, the `why` command accepts a `--cache` parameter, which is used to specify a YAML file containing previous output from the [`query --to-yaml`](https://github.com/square/cocoapods-query) command (from the [query plugin](https://github.com/square/cocoapods-query)). When the plugin sees the `--cache` parameter, it will use the data in this file instead of rebuiding the data from the current CocoaPods instance.

# Related Work

This plugin was inspired by:

* [yarn why](https://classic.yarnpkg.com/en/docs/cli/why/): It is similar to `pod why` but additionally provides information on the file sizes of the dependencies.
* [bazel query](https://docs.bazel.build/versions/master/query-how-to.html): Bazel offers a query language that can find the paths between two dependencies with `bazel query "allpaths(...)" --graph`.
* [dependencies](https://github.com/segiddins/cocoapods-dependencies): This CocoaPods plugin produces a graph of a single pod's dependencies.
* [graph](https://github.com/erickjung/cocoapods-graph): This CocoaPods plugin produces a wheel graph of all dependencies in a project.

# Development

For local development of this plugin, the simplest approach is to install it into an existing app via absolute path. For example, if the code is in a directory called `projects/cocoapods-why` off the home directory, add the following line to the app's Gemfile:

    gem 'cocoapods-why', path: "#{ENV['HOME']}/projects/cocoapods-why"

You can then make changes to the code and they will be executed when using the `why` command from the app's directory.

# Release Process

1. Bump version number in cocoapods_why.rb
2. Run `bundle update` to update Gemfile.lock
3. Make sure tests still pass: `rake spec`
4. (Optional) Run Rubocop on all source files
5. Build the gem: `gem build cocoapods-why.gemspec`
6. Publish the gem: `gem push cocoapods-why-1.0.gem`

# Copyright

Copyright 2020 Square, Inc.
