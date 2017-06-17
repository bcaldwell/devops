# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'helpers/ansible'
require 'helpers/secrets'
require 'helpers/server'
require 'helpers/tasks'
require 'helpers/unix_crypt'

require 'optparse'
require 'yaml'

require 'byebug'

module Gitlab
  class RunnerSetup
    PROJECT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

    def initialize
      @options = {}
      @options[:config_dir] = File.join(PROJECT_DIR, "config")
      @options[:ejson_file] = File.join(@options[:config_dir], "secrets.ejson")

      @options[:hostname] = "gitlab-docker-runner"

      playbook_dir = File.join(PROJECT_DIR, 'ansible/playbooks')
      role_dir = File.join(PROJECT_DIR, 'ansible/roles')

      @ansible = Ansible.new(playbook_dir: playbook_dir, role_dir: role_dir, default_host: "gitlab-runner")
      @secrets = Secrets.new(@options[:ejson_file])
      @secrets.check_required([:gitlab_registration_url, :gitlab_registration_token])

      @node = {
        "user" => "root"
      }

      OptionParser.new do |opts|
        opts.banner = "Usage: gitlab-runner-setup [options]"

        opts.on('--ip NAME', 'node ip address') { |v| @node["ip"] = v }
        opts.on('-u', '--user NAME', 'node ip address') { |v| @node["user"] = v }
      end.parse!

      raise "ip for node not provided" unless @node["ip"]
    end

    def run
      options = @options
      secrets = @secrets
      ansible = @ansible
      node = @node

      Tasks.new_task "Pinging Nodes" do
        list do
          node['alive'] = Server.ping(node)
          [node]
        end

        list_logger do |node|
          if node['alive'] == true
            logger.puts_coloured("{{green:┃ ✓}} #{node['ip']}")
          else
            logger.puts_coloured("{{red:┃ ✗}} #{node['ip']}")
            false
          end
        end
      end

      Tasks.new_task "changing hostname", list_title: "Hostnames to change", end_check: false do
        check? do
          @list = [node]
          (Server.hostname(node) == options[:hostname])
        end

        list_logger do |node|
          logger.log("#{node['ip']} -> #{options[:hostname]}")
        end

        exec do
          Server.change_hostname(node, options[:hostname])
        end
      end

      Tasks.new_task "Install python" do
        check? do
          Server.remote_check(node, "which python")
        end
        exec do
          ansible.run_playbook(node, 'ansible-bootstrap-ubuntu-16.04')
        end
      end

      Tasks.new_task "Setup runner", end_check: false do
        check? { false }
        exec do
          ansible.run_playbook(node, 'gitlab-runner-setup', options: {
            registration_token: secrets.gitlab_registration_token,
            registration_url: secrets.gitlab_registration_url
          })
        end
      end

      Tasks.new_task "Adding cloud user", end_check: false do
        check? { false }
        exec do
          ansible.run_playbook(node, "cloud-user", options: {
            user_password: UnixCrypt.build(secrets.cloud_user_password)
          })
        end
      end

      Tasks.run
    end
  end
end

Gitlab::RunnerSetup.new.run if __FILE__ == $PROGRAM_NAME
