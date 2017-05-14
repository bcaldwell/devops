require 'helpers/ansible'
require 'helpers/secrets'

require 'optparse'
require 'yaml'

require 'byebug'
module Kubernetes
  class Base
    PROJECT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '../..'))

    def initialize
      @options = {}
      @options[:config_dir] = File.join(PROJECT_DIR, "config")
      @options[:ejson_file] = File.join(@options[:config_dir], "secrets.ejson")
      @options[:config_file] = File.join(@options[:config_dir], 'clusters', 'kubernetes.yml')
      @options[:kubeconfig] = File.join(@options[:config_dir], "kubeconfigs", "cluster.yml")

      playbook_dir = File.join(PROJECT_DIR, 'ansible/playbooks')
      role_dir = File.join(PROJECT_DIR, 'ansible/roles')

      @options[:master_hostname] = "kube-master"
      @options[:node_hostname] = "kube-node-{{number}}"
      @options[:node_hostname_regex] = /^kube-node-(\d*)$/


      @ansible = Ansible.new(playbook_dir: playbook_dir, role_dir: role_dir, default_host: "kubernetes")
      @secrets = Secrets.new(@options[:ejson_file])

      OptionParser.new do |opts|
        opts.banner = "Usage: kubernetes-setup [options]"

        opts.on('-c', '--config NAME', 'config file') { |v| @options[:config_file] = File.expand_path(v) }
        opts.on('-c', '--kubeconfig NAME', 'kubeconfig file') { |v| @options[:kubeconfig] = File.expand_path(v) }

      end.parse!

      FileUtils.mkdir_p(@options[:config_dir]) unless File.exist?(@options[:config_dir])

      read_and_filter
    end

    protected

    def read_and_filter
      config = YAML.load_file(@options[:config_file])

      @nodes = []

      @master = {}
      @workers = []
      @remove = []

      config.each do |node|
        next @remove << node if node["remove"] == true
        @nodes << node
        case node['role']
        when 'node'
          @workers << node
        when nil
          node["role"] = "node"
          @workers << node
        when 'master'
          next @master = node if @master.empty?
          raise 'only 1 master node is supported'
        else
          raise "invalid node type: #{node.inspect}"
        end
      end
    end

    def ping_nodes
      Tasks.new_task "Pinging Nodes" do
        list do
          Parallel.map(nodes) do |node|
            node['alive'] = if Server.ping(node)
              true
            else
              false
            end
            node
          end
        end

        list_logger do |node|
          if node['alive'] == true
            logger.puts_coloured("{{green:┃ ✓}} #{node['ip']}   role: #{node['role']}")
          else
            logger.puts_coloured("{{red:┃ ✗}} #{node['ip']}   role: #{node['role']}")
            false
          end
        end
      end
    end
  end
end
