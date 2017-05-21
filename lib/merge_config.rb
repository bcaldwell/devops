require 'yaml'
require 'fileutils'

config_file = ARGV.first

DefaultConfig = File.join(Dir.home, ".kube/config")

abort "✗ must pass in a config file" if config_file.nil?
abort "✗ config file \x1b[34m#{config_file}\x1b[0m doesnt exist" unless File.exist?(config_file)

if File.exist?(DefaultConfig)
  puts "🐧 merging default config at \x1b[34m#{DefaultConfig}\x1b[0m with \x1b[34m#{config_file}\x1b[0m"

  config = YAML.load_file(config_file)
  default = YAML.load_file(DefaultConfig)

  new_config = default.clone

  %w(clusters contexts preferences users).each do |section|
    case default[section]
    when Array
      new_config[section] = default[section].concat(config[section]).uniq
    when Hash
      new_config[section] = default[section].merge(config[section])
    else
      raise "unknown type when merging"
    end
  end

  File.open(DefaultConfig, 'w') do |out|
    YAML.dump(new_config, out)
  end

else
  puts "🐧 copying config to \x1b[34m#{DefaultConfig}\x1b[0m"
  FileUtils.copy(config_file, DefaultConfig)
end
