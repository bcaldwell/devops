# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'helpers/printer'
require 'helpers/ansible'
require 'helpers/tasks'
require 'helpers/server'

require 'yaml'
require 'parallel'
require 'fileutils'

require 'byebug'

# node, master, worker

module Kubernetes
  class Setup
    PROJECT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    def initialize
      @config_dir = File.join(PROJECT_DIR, "config")

      playbook_dir = File.join(PROJECT_DIR, 'ansible/playbooks')
      role_dir = File.join(PROJECT_DIR, 'ansible/roles')

      @ansible = Ansible.new(playbook_dir: playbook_dir, role_dir: role_dir, default_host: "kubernetes")

      @config_file = File.join(@config_dir, 'kubernetes-setup.yml')

      @master_hostname = "kube-master"
      @node_hostname = "kube-node-{{number}}"
      @node_hostname_regex = /^node-(\d*)$/
    end

    def run
      FileUtils.mkdir_p(@config_dir) unless File.exist?(@config_dir)

      read_and_filter

      nodes = @nodes
      master = @master
      workers = @workers

      ansible = @ansible

      cluster_config_file = File.join(@config_dir, "cluster.conf")

      Tasks.new_task "Master node" do
        list { [master] }
        list_logger { |node| logger.log(node["ip"]) }
      end

      Tasks.new_task "Nodes" do
        list { workers }
        list_logger { |node| logger.log(node["ip"]) }
      end

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

      Tasks.new_task "Upgrade ubuntu 14 to 16", list_title: "Nodes to be upgraded from ubuntu 14 to 16" do
        check? do
          @list = parallel_list nodes do |node|
            output = Server.remote_command(node, "lsb_release -a")
            version = output[/Release:\s(.*)/, 1].strip
            Gem::Version.new(version) >= Gem::Version.new('16')
          end
          @list.any?
        end
        exec do
          ansible.run_playbook(@list, '16upgrade')
        end
      end

      Tasks.new_task "Bootstrapping nodes", list_title: "Nodes to bootstrap" do
        check? do
          @list = parallel_list nodes do |node|
            Server.remote_check(node, "which kubeadm && which kubelet && which kubectl")
          end
          @list.any?
        end
        exec do
          ansible.run_playbook(nodes, 'kubernetes/kubernetes-bootstrap')
        end
      end

      Tasks.new_task "Bootstrapping master", list_title: "Master to bootstrap" do
        check? do
          @list = parallel_list [master] do |node|
            Server.remote_check(node, "kubectl cluster-info")
          end
          @list.any?
        end
        exec do
          ansible.run_playbook([node], 'kubernetes/kubernetes-master')
        end
      end

      Tasks.new_task "Joining nodes to cluster", list_title: "Nodes to join" do
        check? do
          @list = parallel_list workers do |node|
            Server.remote_check(node, "tail -n 1 /etc/kubernetes/kubelet.conf")
          end
          @list.any?
        end
        exec do
          run_playbook(nodes, 'kubernetes/kubernetes-node', join_token: get_join_token(master), master_ip: master["ip"])
        end
      end

      Tasks.new_task "Copying over cluster configuration file" do
        check? { File.exist?(cluster_config_file) }
        exec do
          logger.puts_blue("Downloading kubeconfig to #{cluster_config_file}")
          Server.download!(master, "/etc/kubernetes/admin.conf", cluster_config_file)
        end
      end

      Tasks.run
    end

    private

    def read_and_filter
      config = YAML.load_file(@config_file)

      @nodes = config.select { |node| node["remove"] != true }

      @master = {}
      @workers = []

      @nodes.each do |node|
        case node['role']
        when 'node'
          @workers << node
        when 'master'
          next @master = node if @master.empty?
          raise 'only 1 master node is supported'
        else
          raise "invalid node type: #{node.inspect}"
        end
      end

      raise 'no master node' if @master.empty?
    end

    def check_hostname(node)
      puts node["hostname"]
    end

    def set_hostname(nodes)
      Parallel.each(nodes) do |node|
        host = remote_host(node)
        on host do |_host|
          %w(/etc/hostname /etc/hosts).each do |file|
            execute :sed, "-i 's/#{node['current_hostname']}/#{node['hostname']}/g' #{file}"
          end
          execute :hostname, node['hostname']
        end
      end
    end
  end
end

def parallel_list(nodes)
  list = Parallel.map(nodes) do |node|
    yield node
  end

  nodes.select.with_index { |_, i| list[i] }
end

############################################################
# Main script
#
############################################################
if false

  config = Parallel.map(config) { |node| node_hostname(node) }
  # hash of taken hostname number. Initialize with true to disable 0
  # initialize with all nil so there is atleast space for each node
  hostname_db = [true, *[nil] * config.size]
  config = Parallel.map(config) do |node|
    if node["role"] == "master"
      node["hostname"] = MasterHostname
      next node
    end

    num = node["current_hostname"][NodeHostnameRegex, 1]

    if num
      hostname_db[num.to_i] = true
      node["hostname"] = node["current_hostname"]
    end
    node
  end
  config = config.map do |node|
    next node if node["hostname"]
    number = hostname_db.index(nil)
    node["hostname"] = NodeHostname.sub("{{number}}", number.to_s)
    hostname_db[number] = true
    node
  end

  node_to_set_hostname = config.select { |c| c["hostname"] != c["current_hostname"] }
  if node_to_set_hostname.any?
    put_header("Node to change hostname on")
    node_to_set_hostname.each { |node| log("#{node['ip']}    #{node['current_hostname']} -> #{node['hostname']}") }
    put_footer true

    put_header('Changing hostnames')
    successful = set_hostname(node_to_set_hostname)
    put_footer successful
  else
    puts_coloured("{{green: ✓}} Changing hostnames (already done)")
  end


end

Kubernetes::Setup.new.run if __FILE__ == $PROGRAM_NAME
