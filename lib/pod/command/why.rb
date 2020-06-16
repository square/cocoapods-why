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
      self.description = 'If both source and target are given, all paths between them are shown. If target is omitted, all pods that depend on the source (directly or transitively) are shown.'

      self.arguments = [CLAide::Argument.new('source', true), CLAide::Argument.new('target', false)]

      def self.options
        [
          ['--to-yaml=FILE', 'Output the results in YAML format to the given file'],
          ['--to-dot=FILE', 'Output the results in DOT (GraphViz) format to the given file'],
          ['--cache=FILE', 'Load the dependency data from the given YAML file (created previously with the "query" command) instead of from the current CocoaPods instance']
        ].concat(super)
      end

      def initialize(argv)
        super
        @source = argv.shift_argument
        @target = argv.shift_argument
        @to_yaml = argv.option('to-yaml')
        @to_dot = argv.option('to-dot')
        @cache = argv.option('cache')
      end

      def validate!
        super
        help! if @source.nil?
      end

      def run
        UI.puts 'Loading dependencies...'
        all_dependencies = all_dependencies(targets)
        [@source, @target].compact.each { |pod| help! "Cannot find pod named #{pod}" if all_dependencies[pod].nil? }
        graph = make_graph(all_dependencies)
        @target.nil? ? find_reverse_dependencies(@source, graph) : find_all_dependency_paths(@source, @target, graph)
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
          target_dependencies = target[:dependencies].delete_if { |dep| dep.include? '/' } # Remove subspecs
          [target[:name], target_dependencies]
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
          targets.each { |target| graph.add_edge(source, target) }
        end
        graph
      end

      # Computes and returns all possible paths between a source vertex and a target vertex in a directed graph.
      # It does this by performing a DFS and, whenever the target is discovered (or re-discovered), the current
      # DFS stack is captured as one of the possible paths.
      #
      # @note Back edges are ignored because the input graph is assumed to be acyclic.
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
        dfs_stack = [source] # RGL uses recursion for DFS and does not expose a stack, so we build one as we go.
        all_paths = []
        visitor = RGL::DFSVisitor.new(graph)
        visitor.set_tree_edge_event_handler do |_, v|
          dfs_stack << v
          all_paths << dfs_stack.dup if v == target
        end
        visitor.set_forward_edge_event_handler do |_, v|
          dfs_stack << v
          all_paths << dfs_stack.dup if v == target
          dfs_stack.pop
        end
        graph.depth_first_visit(source, visitor) { dfs_stack.pop }
        all_paths
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
        UI.puts "Why does #{source} depend on #{target}?"

        all_paths = all_paths(source, target, graph)

        all_paths.each do |path|
          UI.puts path.join(' ⟶   ')
        end

        File.open(@to_yaml, 'w') { |file| file.write(all_paths.to_yaml) } if @to_yaml
        File.open(@to_dot, 'w') { |file| file.write(all_paths_graph(graph, all_paths).to_dot_graph.to_s) } if @to_dot
      end

      # Finds and prints all pods that depend on source (directly or transitively).
      def find_reverse_dependencies(source, graph)
        UI.puts "What depends on #{source}?"

        tree = graph.reverse.bfs_search_tree_from(source)
        graph = graph.vertices_filtered_by { |v| tree.has_vertex? v }
        sorted_dependencies = graph.vertices.sort
        sorted_dependencies.delete(source)
        sorted_dependencies.each { |dependency| UI.puts dependency }

        File.open(@to_yaml, 'w') { |file| file.write(sorted_dependencies.to_s) } if @to_yaml
        File.open(@to_dot, 'w') { |file| file.write(graph.to_dot_graph.to_s) } if @to_dot
      end
    end
  end
end
