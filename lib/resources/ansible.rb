class Ansible
  def initialize(playbook_dir: "./ansible/playbooks", role_dir: "./ansible/roles", default_host: "server")
    @playbook_dir = playbook_dir
    @role_dir = role_dir
    @default_host = default_host
  end

  def run_playbook(nodes, playbook, options = {})
    default_options = {
      hosts: @default_host
    }
    options = default_options.merge(options)
    options_string = options.map { |a, b| "#{a}=#{b}" }.join(" ")

    hosts_file = File.join(@playbook_dir, 'kubernetes-setup-hosts')
    playbook_file = File.join(@playbook_dir, "#{playbook}.yml")
    node_entries = nodes.map { |node| ansible_host_entry(node) }
    File.write(hosts_file, "[kubernetes]\n#{node_entries.join("\n")}")

    exit_code = system({ "ANSIBLE_ROLES_PATH" => @role_dir }, 'ansible-playbook', playbook_file, '-i', hosts_file, '-e', options_string.to_s)
    FileUtils.rm(hosts_file)

    exit_code
  end

  def ansible_host_entry(node)
    str = node['ip']
    str += " ansible_user=#{node['user']}" if node['user']
    str += " ansible_ssh_pass=#{node['password']}" if node['password']
    str
  end
end
