require 'kubernetes/base'

require 'helpers/status_cake'
require 'helpers/server'

require 'parallel'

module Kubernetes
  class StatusCake < Kubernetes::Base
    def run
      nodes = @nodes

      api = Helpers::StatusCake.new(@secrets.status_cake_username, @secrets.status_cake_api_key)

      tests = api.all_tests_details(tags: "kube")

      nodes.each_with_index do |node|
        test = tests.find { |t| t["URI"] == node["ip"] }
        node["hostname"] = Server.hostname(node) unless node["hostname"]

        if test
          tests -= [test]
        end
        if test.nil?
          info_printer("Creating test for #{node['hostname']}")
          api.new_ping_test_for_node(node)
        elsif node["hostname"] != test["WebsiteName"]
          info_printer("Updating test for #{node['hostname']}")
          api.update_test_for_node(test["TestID"], node)
        end
      end

      tests.each do |test|
        info_printer("Creating test for #{test['WebsiteName']}")
        api.delete_test(test["TestID"])
      end

      print_footer
    end

    def info_printer(text)
      if @printed.nil?
        Printer.put_header("Updating Status Cake")
        @printed = true
      end
      Printer.puts_success(text)
    end

    def print_footer
      if @printed
        Printer.put_footer
      end
    end
  end
end

Kubernetes::StatusCake.new.run if __FILE__ == $PROGRAM_NAME
