# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'printer'
require 'net/http'
require 'uri'
require 'json'

API_KEY = ENV["CAC_API_KEY"]
raise "CAC_API_KEY env variable not set" if API_KEY.nil?

EMAIL = ENV["CAC_EMAIL"]
raise "CAC_EMAIL env variable not set" if EMAIL.nil?

CPU = 2
RAM = 1024
STORAGE = 20
OS = 27

put_header("Configuration")
log("CPU: #{CPU}")
log("RAM: #{RAM}")
log("STORAGE: #{STORAGE}")
log("OS: #{OS}")
put_footer true

put_header("Requesting server to be built")
uri = URI.parse("https://panel.cloudatcost.com/api/v1/cloudpro/build.php")
body = {
  login: EMAIL,
  key: API_KEY,
  cpu: CPU,
  ram: RAM,
  storage: STORAGE,
  os: OS
}
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
request = Net::HTTP::Post.new(uri.request_uri)
request.set_form_data(body)
response = http.request(request)
log("Status: #{response.code}")
server_built = JSON.parse(response.body)
log JSON.pretty_generate(server_built)
put_footer true

put_header("Setting run mode to normal")
uri = URI.parse('https://panel.cloudatcost.com/api/v1/listservers.php')
params = {
  login: EMAIL,
  key: API_KEY
}
uri.query = URI.encode_www_form(params)
resp = JSON.parse(Net::HTTP.get(uri))
log "List server request status: #{resp['status']}"
server = resp["data"].select { |node| node["servername"] == server_built["servername"] }.first
# Add params to URI
uri.query = URI.encode_www_form(params)

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
log("Status: #{response.code}")
server = JSON.parse(response.body)
log JSON.pretty_generate(server)
put_footer true
