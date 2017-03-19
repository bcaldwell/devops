# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'printer'
require 'yaml'
require 'parallel'
require 'fileutils'

require 'sshkit'
require 'sshkit/dsl'
include SSHKit::DSL

require 'byebug'

module Kubernetes
  class Setup
    ProjectDir = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    ConfigDir = File.join(ProjectDir, "config")

    ConfigFile = File.join(ConfigDir, 'kubernetes-setup.yml')
    PlaybookDir = File.join(ProjectDir, 'ansible/playbooks')
    RolePath = File.join(ProjectDir, 'ansible/roles')

    MasterHostname = "kube-master"
    NodeHostname = "kube-node-{{number}}"
    NodeHostnameRegex = /^node-(\d*)$/

    def initialize
    end

    def run
    end
  end
end

############################################################
#
# Ansible helpers
#
############################################################

def run_playbook(nodes, playbook, options = {})
  default_options = {
    hosts: "kubernetes"
  }
  options = default_options.merge(options)
  options_string = options.map { |a, b| "#{a}=#{b}" }.join(" ")

  hosts_file = File.join(PlaybookDir, 'kubernetes-setup-hosts')
  playbook_file = File.join(PlaybookDir, "#{playbook}.yml")
  node_entries = nodes.map { |node| ansible_host_entry(node) }
  File.write(hosts_file, "[kubernetes]\n#{node_entries.join("\n")}")

  exit_code = system({ "ANSIBLE_ROLES_PATH" => RolePath }, 'ansible-playbook', playbook_file, '-i', hosts_file, '-e', options_string.to_s)
  FileUtils.rm(hosts_file)

  exit_code
end

def ansible_host_entry(node)
  str = node['ip']
  str += " ansible_user=#{node['user']}" if node['user']
  str += " ansible_ssh_pass=#{node['password']}" if node['password']
  str
end
############################################################

############################################################
# SSH shell helpers
#
############################################################

# Remote_check connects to node through ssh.
# Returns the output
def remote_command(node, *command)
  host = remote_host(node)
  output = ''
  on host do |_host|
    output = capture(*command)
  end
  output
end

def remote_host(node)
  host = SSHKit::Host.new(node['ip'])
  host.user = node['user'] if node['user']
  host.password = node['password'] if node['password']
  host
end

def remote_check(node, *command)
  success = true
  begin
    output = remote_command(node, *command)
  rescue
    success = false
  end
  success
end
############################################################

############################################################
# Checks
#
############################################################
def check_ping(node)
  `ping -c 1 "#{node['ip']}"`
  $CHILD_STATUS.success?
end

def check_ubuntu_16(node)
  output = remote_command(node, "lsb_release -a")
  version = output[/Release:\s(.*)/, 1].strip
  Gem::Version.new(version) >= Gem::Version.new('16')
end

def upgrade_nodes(nodes)
  run_playbook(nodes, '16upgrade')
end

def check_kube_bootstraped(node)
  remote_check(node, "which kubeadm && which kubelet && which kubectl")
end

def kube_bootstrap(nodes)
  run_playbook(nodes, 'kubernetes/kubernetes-bootstrap')
end

def check_kube_master(node)
  remote_check(node, "kubectl cluster-info")
end

def kube_master_bootstrap(node)
  run_playbook([node], 'kubernetes/kubernetes-master')
end

def check_kube_node(node)
  remote_check(node, "tail -n 1 /etc/kubernetes/kubelet.conf")
end

def kube_node_bootstrap(master, nodes)
  run_playbook(nodes, 'kubernetes/kubernetes-node', join_token: get_join_tocken(master), master_ip: master["ip"])
end

def node_hostname(node)
  hostname = remote_command(node, "hostname")
  node["current_hostname"] = hostname
  node
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
############################################################

############################################################
# Kube helpers
#
############################################################

def get_join_tocken(master_node)
  command = 'kubectl -n kube-system get secret clusterinfo -o yaml | grep token-map | awk \'{print $2}\' | base64 -d | sed "s|{||g;s|}||g;s|:|.|g;s/\"//g;" | xargs echo'
  remote_command(master_node, command)
end

def download_config(master, local_location)
  host = remote_host(master)
  on host do
    download! "/etc/kubernetes/admin.conf", local_location
  end
end
############################################################

############################################################
# Main script
#
############################################################
FileUtils.mkdir_p(ConfigDir) unless File.exist?(ConfigDir)

config = YAML.load_file(ConfigFile)

master = {}
nodes = []

config.each do |node|
  case node['role']
  when 'node'
    nodes << node
  when 'master'
    next master = node if master.empty?
    raise 'only 1 master node is supported'
  else
    raise "invalid node type: #{node.inspect}"
  end
end

raise 'no master node' if master.empty?

put_header('Master Node')
log master['ip']
put_footer true

put_header('Nodes')
nodes.each { |node| log node['ip'] }
put_footer true

successful = true
put_header('Pinging Nodes')
alive_config = Parallel.map(config) do |node|
  node['alive'] = if check_ping(node)
    true
  else
    false
  end
  node
end
alive_config.each do |node|
  if node['alive'] == true
    puts_coloured("{{green:┃ ✓}} #{node['ip']}   role: #{node['role']}")
  else
    puts_coloured("{{red:┃ ✗}} #{node['ip']}   role: #{node['role']}")
    successful = false
  end
end
put_footer successful

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

nodes_to_upgrade = config.select { |node| !check_ubuntu_16(node) }
if nodes_to_upgrade.any?
  put_header("Nodes to be upgraded from ubuntu 14 to 16")
  nodes_to_upgrade.each { |node| log node['ip'] }
  put_footer true

  put_header('Upgrading nodes from ubuntu 14 to 16. This will take a while')
  successful = upgrade_nodes(nodes_to_upgrade)
  put_footer successful
else
  puts_coloured("{{green: ✓}} Upgrade ubuntu 14 to 16 (already done)")
end

node_to_bootstrap = config.select { |node| !check_kube_bootstraped(node) }
if node_to_bootstrap.any?
  put_header("'Nodes to be bootstraped")
  node_to_bootstrap.each { |node| log node['ip'] }
  put_footer true

  put_header('Bootstrapping nodes')
  successful = kube_bootstrap(node_to_bootstrap)
  put_footer successful
else
  puts_coloured("{{green: ✓}} Bootstrapping nodes (already done)")
end

bootstrap_master = check_kube_master(master)
if bootstrap_master
  puts_coloured("{{green: ✓}} Bootstrapping master (already done)")
else
  put_header("Bootstrapping master")
  successful = kube_master_bootstrap(master)
  put_footer successful
end

node_to_join = nodes.select { |node| !check_kube_node(node) }
if node_to_join.any?
  put_header("Nodes that will join cluster")
  node_to_join.each { |node| log node['ip'] }
  put_footer true

  put_header('Joining nodes')
  successful = kube_node_bootstrap(master, node_to_join)
  puts_blue "Settling down for 10 seconds"
  sleep 10
  put_footer successful
else
  puts_coloured("{{green: ✓}} Joining nodes (already done)")
end

put_header("List nodes from master node")
puts remote_command(master, "kubectl get nodes")
put_footer true

cluster_conf = File.join(ConfigDir, "cluster.conf")
unless File.exist?(cluster_conf)
  put_header("Copy over cluster configuration file")
  puts_blue "Downloading kubeconfig to #{cluster_conf}"
  download_config(master, cluster_conf)
  put_footer true
end

puts_coloured "{{green: ✓✓✓ 😊 Successfully created cluster 😊 }}"
############################################################
