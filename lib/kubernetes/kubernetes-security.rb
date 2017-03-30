# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'kubernetes_base'
require 'helpers/tasks'
require 'helpers/unix_crypt'

module Kubernetes
  class Security < Kubernetes::Base
    def run

      nodes = @nodes
      ansible = @ansible
      secrets = @secrets

      Tasks.new_task "Adding cloud user", end_check: false do
        check? { false }
        exec do
          ansible.run_playbook(nodes, "cloud-user", options: {
            user_password: UnixCrypt.build(secrets.cloud_user_password)
          })
        end
      end

      Tasks.run
    end
  end
end

Kubernetes::Security.new.run if __FILE__ == $PROGRAM_NAME
