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
        begin
          output = capture(*command)
        rescue StandardError => e
          # puts "ERROR: #{e}"
          # raise e
        end
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
      `ping -c 3 "#{node['ip']}"`
      $CHILD_STATUS.success?
    end

    def download!(node, remote, local)
      host = remote_host(node)
      on host do
        download! remote, local
      end
    end

    def hostname(node)
      remote_command(node, "hostname")
    end

    def change_hostname(node, hostname, current_hostname = nil)
      current_hostname = hostname(node) if current_hostname.nil?
      host = remote_host(node)
      on host do |_host|
        %w(/etc/hostname /etc/hosts).each do |file|
          execute :sed, "-i 's/#{current_hostname}/#{hostname}/g' #{file}"
        end
        execute :hostname, node['hostname']
      end
    end
  end
end
