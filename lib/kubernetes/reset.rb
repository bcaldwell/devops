require 'kubernetes/base'
require 'helpers/printer'
require 'helpers/tasks'
require 'helpers/server'

require 'yaml'
require 'parallel'
require 'fileutils'
require 'optparse'
require 'byebug'

module Kubernetes
  class Reset < Kubernetes::Base
    def run
      remove = @remove
      ansible = @ansible

      options = @options

      cluster_config_file = File.join(@options[:config_dir], "cluster.conf")

      Tasks.new_task "Pinging Nodes" do
        list do
          Parallel.map(remove) do |node|
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

      Tasks.new_task "reseting nodes", end_check:false do
        check? do
          @list = remove
          @list.empty?
        end
        exec do
          ansible.run_playbook(@list, 'kubernetes/reset')
        end
      end

      Tasks.run
    end
  end
end

Kubernetes::Reset.new.run if __FILE__ == $PROGRAM_NAME
