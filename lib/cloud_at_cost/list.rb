# Add current directory to load path
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'helpers/printer'
require 'helpers/secrets'

require 'net/http'
require 'uri'
require 'json'
require 'yaml'

PROJECT_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))

secrets = Secrets.new(File.join(PROJECT_DIR, "..", "config", "secrets.ejson"), [:cloud_at_cost_email, :cloud_at_cost_api_key])

API_KEY = secrets.cloud_at_cost_api_key

EMAIL = secrets.cloud_at_cost_email

Printer.put_header "Server data"

uri = URI.parse('https://panel.cloudatcost.com/api/v1/listservers.php')
params = {
  login: EMAIL,
  key: API_KEY
}
uri.query = URI.encode_www_form(params)
resp = Net::HTTP.get_response(uri)

Printer.log "List server request status: #{resp.code}"

if resp.message
  Printer.puts_failure("Empty response recieved")
  Printer.put_footer(false)
  exit 1
end

resp = JSON.parse(resp.message)

resp["data"].each do |node|
  server_data = [
    {
      "ip" => node["ip"],
      "user" => "root",
      "password" => node["rootpass"]
    }
  ]
  puts server_data.to_yaml
end
Printer.put_footer
