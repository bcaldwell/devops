# require "ejson"

require_relative './printer'
require 'open3'
require 'pathname'
require 'json'

class Secrets
  def initialize(config_file = nil, required = [])
    @secrets = {}
    unless config_file.nil?
      load_from_ejson(config_file)
      load_from_env(@secrets.keys)
    end
    unless required.empty?
      load_from_env(required)
      check_required(required)
    end
  end

  def load_from_ejson(ejson_path)
    ejson_path = File.absolute_path(ejson_path) unless Pathname.new(ejson_path).absolute?
    raise "config file: #{ejson_path} not found" unless File.exist?(ejson_path)

    encrypted_json = JSON.parse(File.read(ejson_path))
    public_key = encrypted_json['_public_key']
    private_key_path = "/opt/ejson/keys/#{public_key}"
    raise "Private key is not listed in #{private_key_path}." unless File.exist?(private_key_path)

    output, status = Open3.capture2e("ejson", "decrypt", ejson_path.to_s)
    raise "ejson: #{output}" unless status.success?

    secrets = JSON.parse(output)
    secrets = hash_symblize_keys(secrets)

    @secrets.merge!(secrets)
  end

  def load_from_env(keys)
    secrets = {}
    keys.each do |key|
      key = key.to_s
      next if key.start_with?("_")
      value = ENV[key.upcase]
      secrets[key] = value unless value.nil?
    end

    secrets = hash_symblize_keys(secrets)
    @secrets.merge!(secrets)
  end

  def check_required(required = [])
    required.each { |key| raise "required secrets not set: #{key}" if @secrets[key].nil? }
  end

  def method_missing(key, *args)
    value = @secrets[key]
    return value unless value.nil?
    Printer.puts_failure "no secret for key: #{key}"
    super
  end

  def respond_to_missing?(*args)
    super
  end

  def hash_symblize_keys(hash)
    hash.keys.each do |key|
      hash[(begin
        key.to_sym
      rescue
        key
      end) || key] = hash.delete(key)
    end
    hash
  end
end

# a = Secrets.new("config/secrets.ejson", [:hello])

# a.check_required([:cloud_at_cost_email, :cloud_at_cost_api_key])

# puts a.cloud_at_cost_email
# puts a.hello
