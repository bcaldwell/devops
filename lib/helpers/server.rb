require 'sshkit'
require 'sshkit/dsl'

class Server
  class << self
    include SSHKit::DSL
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
        remote_command(node, *command)
      rescue
        success = false
      end
      success
    end

    def ping(node)
      `ping -c 1 "#{node['ip']}"`
      $CHILD_STATUS.success?
    end

    def download!(node, remote, local)
      host = remote_host(node)
      on host do
        download! remote, local
      end
    end
  end
end
