# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'kubernetes_base'
require 'helpers/tasks'
require 'helpers/unix_crypt'

require 'byebug'

module Kubernetes
  class Security < Kubernetes::Base
    def run

      master = @master
      nodes = @nodes
      ansible = @ansible
      secrets = @secrets
      config_file = @options[:config_file]

      Tasks.new_task "Adding cloud user", end_check: false do
        check? do
          @list = nodes.select{ |node| node["user"] != "cloud" }
        end

        exec do
          ansible.run_playbook(nodes, "cloud-user", options: {
            user_password: UnixCrypt.build(secrets.cloud_user_password)
          })
        end
      end

      Tasks.new_task "Updating yaml config", end_check: false do
        check? { false }
        exec do
          File.write("#{config_file}.backup", nodes.to_yaml)

          nodes.each_with_index do |node, index|
            node["user"] = "cloud"
            node.delete("password")

            nodes[index] = node
          end
          File.write(config_file, nodes.to_yaml)
        end
      end

      Tasks.new_task "Setting up firewall", end_check: false do
        check? { false }
        exec do
          ansible.run_playbook(nodes, "kubernetes/firewall", options: {
            node_ips: nodes.map { |node| node["ip"] }.to_s.gsub!(/\s+/, ''),
            master_ip: master["ip"]
          })
        end
      end

      Tasks.run
    end
  end
end

Kubernetes::Security.new.run if __FILE__ == $PROGRAM_NAME
