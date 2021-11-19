# frozen_string_literal: true

require 'cocoapods'
require 'rgl/adjacency'
require 'rgl/dot'
require 'rgl/implicit'
require 'rgl/traversal'
require 'yaml'

module Pod
  class Command
    class Why < Command
      self.summary = 'Shows why one pod depends on another'
      self.description = 'If both source and target are given, all paths between them are shown. If target is omitted, all of the source\'s dependencies (direct and transitive) are shown.'

      self.arguments = [CLAide::Argument.new('source', true), CLAide::Argument.new('target', false)]

      def self.options
        [
          ['--reverse', 'Shows reverse dependencies (what depends on the source instead of what the source depends on). Only valid when target is omitted.'],
          ['--direct', 'Shows only the dependencies the source depends directly on (or only what depends directly on the source if used in conjunction with --reverse). Only valid when target is omitted.'],
          ['--to-yaml=FILE', 'Output the results in YAML format to the given file'],
          ['--to-dot=FILE', 'Output the results in DOT (GraphViz) format to the given file'],
          ['--cache=FILE', 'Load the dependency data from the given YAML file (created previously with the "query" command) instead of from the current CocoaPods instance']
        ].concat(super)
      end

      def initialize(argv)
        super
        @source = argv.shift_argument
        @target = argv.shift_argument
        @reverse = argv.flag?('reverse')
        @direct = argv.flag?('direct')
        @to_yaml = argv.option('to-yaml')
        @to_dot = argv.option('to-dot')
        @cache = argv.option('cache')
      end

      def validate!
        super
        help! if @source.nil?
      end

      def run
        warn 'Loading dependencies...'
        all_dependencies = all_dependencies(targets)
        [@source, @target].compact.each { |pod| help! "Cannot find pod named #{pod}" if all_dependencies[pod].nil? }
        graph = make_graph(all_dependencies)
        @target.nil? ? find_dependencies(@source, graph, @reverse, @direct) : find_all_dependency_paths(@source, @target, graph)
      end

      private

      # Returns an of array of all pods in the sandbox with their dependencies. Each element
      # in the array is a hash of the pod's name and its dependencies.
      #
      # If a cache is present, the array is loaded from it instead of from the current instance.
      #
      # @note For projects with a large dependency graph, this function can take a long time to
      #       run if a cache is not given.
      #
      # @return [Array<Hash>] an array of hashes containing pod names and dependencies
      def targets
        return YAML.safe_load(File.read(@cache), permitted_classes: [Symbol]) unless @cache.nil?

        targets = Pod::Config.instance.with_changes(silent: true) do
          Pod::Installer.targets_from_sandbox(
            Pod::Config.instance.sandbox,
            Pod::Config.instance.podfile,
            Pod::Config.instance.lockfile
          ).flat_map(&:pod_targets).uniq
        end

        targets.map { |target| { name: target.name, dependencies: target.root_spec.dependencies.map(&:name) } }
      end

      # Returns a hash of all dependencies found in the given target list. The keys of the hash are
      # pod names and their values are the direct dependencies for that pod (represented as an array
      # of pod names). Pods with no dependencies are mapped to an empty array.
      #
      # @param [Array<Hash>] targets
      #        An array of hashes containing pod names and dependencies
      #
      # @return [Hash<String,Array<String>>] a mapping of pod names to their direct dependencies
      def all_dependencies(targets)
        targets.to_h do |target|
          deps = target[:dependencies] || []
          deps = deps.delete_if { |dep| dep.include? '/' } # Remove subspecs
          [target[:name], deps]
        end
      end

      # Returns a directed dependency graph of all pods in the sandbox. The vertices are pod names, and
      # each edge represents a direct dependency on another pod.
      #
      # @param [Hash<String,Array<String>>] all_dependencies
      #        A hash of pod names to their direct dependencies
      #
      # @return [RGL::DirectedAdjacencyGraph] a directed graph
      def make_graph(all_dependencies)
        graph = RGL::DirectedAdjacencyGraph.new
        all_dependencies.each do |source, targets|
          if targets.empty?
            graph.add_vertex(source)
          else
            targets.each { |target| graph.add_edge(source, target) }
          end
        end
        graph
      end

      # Computes and returns all possible paths between a source vertex and a target vertex in a directed graph.
      #
      # It does this by performing a recursive walk through the graph (like DFS). After returning from a recursive
      # descent through all of a vertex's edges, the vertex is prepended to each returned path and in this way the
      # list of all paths is built up. The recursion stops when the target vertex is discovered.
      #
      # The algorithm described above is exponential in running time, so memoization is used to speed it up.
      # After all paths from a vertex are discovered, the results are stored in a hash. Before processing a vertex,
      # this hash is queried for a previously stored result, which if found is returned instead of recomputed.
      #
      # @note The input graph is assumed to be acyclic.
      #
      # @param [String] source
      #        The vertex at which to begin the search.
      # @param [String] target
      #        The vertex at which to end the search.
      # @param [RGL::DirectedAdjacencyGraph] graph
      #        A directed acyclic graph. The vertices are assumed to be strings (to match the source/target types).
      #
      # @return [Array<Array<String>>] a list of all paths from source to target
      def all_paths(source, target, graph)

        def search(source, target, graph, all_paths)
          return all_paths[source] if all_paths.key?(source)
          return [[target]] if source == target

          source_paths = []
          graph.each_adjacent(source) { |v| source_paths += search(v, target, graph, all_paths) }
          all_paths[source] = source_paths.map { |path| [source] + path }
        end

        search(source, target, graph, {})
      end

      # Converts a list of dependency paths into a graph. The vertices in the paths are
      # assumed to exist in the given graph.
      #
      # @param [RGL::DirectedAdjacencyGraph] graph
      #        A directed graph of pod dependencies
      # @param [Array<Array<String>>] all_paths
      #        A list of paths from one dependency to another
      #
      # @return [Array<Array<String>>] a list of all paths from source to target
      def all_paths_graph(graph, all_paths)
        all_paths_vertices = all_paths.flatten.to_set
        graph.vertices_filtered_by { |v| all_paths_vertices.include? v }
      end

      # Finds and prints all paths from source to target.
      def find_all_dependency_paths(source, target, graph)
        all_paths = all_paths(source, target, graph)

        if all_paths.empty?
          UI.puts "#{source} does not depend on #{target}"
          return
        end

        warn "Why does #{source} depend on #{target}?"

        all_paths.each do |path|
          UI.puts path.join(' ⟶   ')
        end

        File.open(@to_yaml, 'w') { |file| file.write(all_paths.to_yaml) } if @to_yaml
        File.open(@to_dot, 'w') { |file| file.write(all_paths_graph(graph, all_paths).to_dot_graph.to_s) } if @to_dot
      end

      # Finds and prints all pods that source depends on, or all that depend on source (directly or transitively,
      # or only directly if `direct` is true).
      def find_dependencies(source, graph, reverse, direct)
        if reverse
          warn "What depends on #{source}?"
          graph = graph.reverse
        else
          warn "What does #{source} depend on?"
        end

        if direct
          sorted_dependencies = graph.adjacent_vertices(source).sort
        else
          tree = graph.bfs_search_tree_from(source)
          graph = graph.vertices_filtered_by { |v| tree.has_vertex? v }
          sorted_dependencies = graph.vertices.sort
          sorted_dependencies.delete(source)
        end

        if sorted_dependencies.empty?
          UI.puts 'No dependencies found'
        else
          sorted_dependencies.each { |dependency| UI.puts dependency }
        end

        File.open(@to_yaml, 'w') { |file| file.write(sorted_dependencies.to_s) } if @to_yaml
        File.open(@to_dot, 'w') { |file| file.write(graph.to_dot_graph.to_s) } if @to_dot
      end
    end
  end
end
