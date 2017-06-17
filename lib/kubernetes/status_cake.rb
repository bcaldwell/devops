require 'kubernetes/base'

require 'helpers/status_cake'

require 'parallel'

module Kubernetes
  class StatusCake < Kubernetes::Base
    def run
      nodes = @nodes

      api = @api = Helpers::StatusCake.new(@secrets.status_cake_username, @secrets.status_cake_api_key)

      puts api.delete_test(2295146)



      # Tasks.new_task "Pinging Nodes" do
      #   list do
      #     Parallel.map(nodes) do |node|
      #       node['alive'] = if Server.ping(node)
      #         true
      #       else
      #         false
      #       end
      #       node
      #     end
      #   end

      #   list_logger do |node|
      #     if node['alive'] == true
      #       logger.puts_coloured("{{green:┃ ✓}} #{node['ip']}   role: #{node['role']}")
      #     else
      #       logger.puts_coloured("{{red:┃ ✗}} #{node['ip']}   role: #{node['role']}")
      #     end
      #   end
      # end

      # Tasks.new_task "ssh access" do
      #   list do
      #     Parallel.map(nodes) do |node|
      #       node['alive'] = true
      #       begin
      #         Server.remote_command(node, "ls")
      #       rescue Net::SSH::ConnectionTimeout
      #         node['alive'] = false
      #       end
      #       node
      #     end
      #   end
      #   list_logger do |node|
      #     if node['alive'] == true
      #       logger.puts_coloured("{{green:┃ ✓}} #{node['ip']}   role: #{node['role']}")
      #     else
      #       logger.puts_coloured("{{red:┃ ✗}} #{node['ip']}   role: #{node['role']}")
      #     end
      #   end
      # end

      # Tasks.run
    end
  end
end

Kubernetes::StatusCake.new.run if __FILE__ == $PROGRAM_NAME
