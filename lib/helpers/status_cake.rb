require 'rest-client'
require 'json'
require 'helpers/server'

module Helpers
  class StatusCake
    attr_accessor :default_test

    def initialize(username, api_key, default_test = nil)
      @base_params = {
        API: api_key,
        Username: username,
        accept: :json
      }
      @api_endpoint = RestClient::Resource.new "https://app.statuscake.com/API"
      @default_test = default_test || {
        CheckRate: 300,
        TestType: "PING",
        FollowRedirect: 1
      }
    end

    # example params {tags: "kube,kubernetes"}
    def all_tests(params = {})
      request_params = {
        params: params
      }.merge(@base_params)
      response = @api_endpoint["Tests/"].get request_params
      JSON.parse(response.body)
    end

    def test_details(test_id)
      request_params = {
        params: {
          TestID: test_id
        }
      }.merge(@base_params)
      response = @api_endpoint["Tests/Details"].get request_params
      JSON.parse(response.body)
    end

    def all_tests_details(params)
      tests = all_tests(params)
      tests.map do |test|
        test_details(test["TestID"])
      end
    end

    def delete_test(test_id)
      request_params = {
        params: {
          TestID: test_id
        }
      }.merge(@base_params)
      response = @api_endpoint["Tests/Details"].delete request_params
    end

    def new_test(options)
      options.merge!(@default_test)
      response = @api_endpoint["Tests/Update"].put options, @base_params
    end

    def new_ping_test(name, url)
      new_test(
        WebsiteName: name,
        WebsiteURL: url
      )
    end

    def new_http_test(name, url)
      new_test(
        WebsiteName: name,
        WebsiteURL: url,
        TestType: "HTTP"
      )
    end

    def new_ping_test_for_node(node)
      node["hostname"] = Server.hostname(node) unless node["hostname"]
      new_test(
        WebsiteName: node["hostname"],
        WebsiteURL: node["ip"]
      )
    end
  end
end
