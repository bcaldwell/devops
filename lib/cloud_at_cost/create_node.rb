# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'helpers/printer'
require 'helpers/secrets'

require 'net/http'
require 'uri'
require 'json'
require 'yaml'

PROJECT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

secrets = Secrets.new(File.join(PROJECT_DIR, "config", "secrets.ejson"), [:cloud_at_cost_email, :cloud_at_cost_api_key])

API_KEY = secrets.cloud_at_cost_api_key

EMAIL = secrets.cloud_at_cost_email

CPU = 3
RAM = 2048
STORAGE = 30
OS = 24

# CentOS 6.7 64bit: 1
# CentOS 6.9 64bit: 23
# CentOS-7-64bit: 15
# Debian-8-64bit: 3
# Debian-8.8-64bit: 22
# FreeBSD-10-1-64bit: 18
# Ubuntu-14.04.1-LTS-64bit: 16
# Ubuntu-16.04.2-LTS-64bit: 24
# Windows 10 64bit: 25
# Windows 2008 R2 64bit: 13
# Windows 2012 R2 64bit: 14
# Windows 7 64bit: 4

DATACENTER = 3

Printer.put_header("Configuration")
Printer.log("CPU: #{CPU}")
Printer.log("RAM: #{RAM}")
Printer.log("STORAGE: #{STORAGE}")
Printer.log("OS: #{OS}")
Printer.log("DATACENTER: #{DATACENTER}")
Printer.put_footer true

Printer.put_header("Requesting server to be built")
uri = URI.parse("https://panel.cloudatcost.com/api/v1/cloudpro/build.php")
body = {
  login: EMAIL,
  key: API_KEY,
  cpu: CPU,
  ram: RAM,
  storage: STORAGE,
  os: OS,
  datacenter: DATACENTER
}
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
request = Net::HTTP::Post.new(uri.request_uri)
request.set_form_data(body)
response = http.request(request)
Printer.log("Status: #{response.code}")
server_built = JSON.parse(response.body)
Printer.log JSON.pretty_generate(server_built)
Printer.put_footer true

Printer.put_header("Setting run mode to normal")

uri = URI.parse("https://panel.cloudatcost.com/api/v1/runmode.php")
body = {
  login: EMAIL,
  key: API_KEY,
  sid: server["sid"],
  mode: "normal"
}
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
request = Net::HTTP::Post.new(uri.request_uri)
request.set_form_data(body)
response = http.request(request)
Printer.log("Status: #{response.code}")
resp = JSON.parse(response.body)
Printer.log JSON.pretty_generate(resp)
Printer.put_footer true


Printer.put_header "Server data"

uri = URI.parse('https://panel.cloudatcost.com/api/v1/listservers.php')
params = {
  login: EMAIL,
  key: API_KEY
}
uri.query = URI.encode_www_form(params)
resp = JSON.parse(Net::HTTP.get(uri))
Printer.log "List server request status: #{resp['status']}"
server = resp["data"].select { |node| node["servername"] == server_built["servername"] }.first

server_data = [
  {
    "ip" => server["ip"],
    "user" => "root",
    "password" => server["rootpass"]
  }
]
puts server_data.to_yaml
Printer.put_footer
