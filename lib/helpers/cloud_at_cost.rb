require "cac/version"
require 'json'

class Cac

  URL = "https://panel.cloudatcost.com/api/v1/"

  def initialize(key = '', login = '')
    @key = key
    @login = login
  end

  def servers
    JSON.parse(RestClient.get("#{URL}listservers.php", {params: {key: @key, login: @login}}){|response, request, result| response })
  end

  def templates
    JSON.parse(RestClient.get("#{URL}listtemplates.php", {params: {key: @key, login: @login}}){|response, request, result| response })
  end

  def tasks
    JSON.parse(RestClient.get("#{URL}listtasks.php", {params: {key: @key, login: @login}}){|response, request, result| response })
  end

  #action must be either: poweron, poweroff, reset
  def power(action, server)
    JSON.parse(RestClient.post("#{URL}powerop.php", {key: @key, login: @login, action: action, sid: server}){|response, request, result| response })
  end

  def console(server)
    JSON.parse(RestClient.post("#{URL}console.php", {key: @key, login: @login, sid: server}){|response, request, result| response })
  end

  def rename(server, name)
    JSON.parse(RestClient.post("#{URL}renameserver.php", {key: @key, login: @login, sid: server, name: name}){|response, request, result| response })
  end

  def rdns(server, hostname)
    JSON.parse(RestClient.post("#{URL}rdns.php", {key: @key, login: @login, sid: server, hostname: hostname}){|response, request, result| response })
  end

  def runmode(server, mode)
    JSON.parse(RestClient.post("#{URL}runmode.php", {key: @key, login: @login, sid: server, mode: mode}){|response, request, result| response })
  end

  # must include:
  #   cpu [1-8]
  #   ram [512-34816] (multiples of 4, ex. 1024, 2048, etc)
  #   storage [10-1000]
  #   os [must be from templateid]
  def build(cpu, ram, storage, os, datacenter = 2)
    JSON.parse(RestClient.post("#{URL}cloudpro/build.php", {key: @key, login: @login, cpu: cpu, ram: ram, storage: storage, os: os, datacenter: datacenter}){|response, request, result| response })
  end

  def delete(server)
    JSON.parse(RestClient.post("#{URL}cloudpro/delete.php", {key: @key, login: @login, sid: server}){|response, request, result| response })
  end

  def resources
    JSON.parse(RestClient.get("#{URL}cloudpro/resources.php", {params: {key: @key, login: @login}}){|response, request, result| response })
  end

end
