begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

require 'yaml'
compatibility = YAML.load(File.read('compatibility'))

kind = File.basename(__FILE__, '.rb')
version = ARGV[0] || raise(ArgumentError, 'missing version')
match = compatibility[kind].select do |e|
  Gem::Requirement.new(e['version']).satisfied_by?(Gem::Version.new(version))
end.tap do |m|
  if m.empty?
    raise ArgumentError, "unmatched requirement for #{kind}:#{version}"
  elsif !m.one?
    raise ArgumentError, "ambiguous version range for #{kind}:#{version}"
  end
end.first
server = ARGV[1] || 'thin'

gemfile(true) do
  source "https://rubygems.org"

  ruby match['ruby']

  gem 'rails', "~> #{version}.0"
  gem server

  match.fetch('gem', []).each do |name, requirement|
    gem name, requirement
  end
end

require "action_controller/railtie"

class App < Rails::Application
  routes.append do
    get "/hello/world" => "hello#world"
  end

  config.consider_all_requests_local = true # display errors
  config.eager_load = true # load everything

  if Gem::Requirement.new('< 4.0').satisfied_by?(Gem.loaded_specs['rails'].version)
    config.secret_token = 'a4e6df27-2f39-41e4-83d2-3bc4d087c910'
  else
    config.secret_key_base = 'a4e6df27-2f39-41e4-83d2-3bc4d087c910'
  end
end

if Gem::Requirement.new('< 5.0').satisfied_by?(Gem.loaded_specs['rails'].version)
  action_controller_api_class = ActionController::Base
else
  action_controller_api_class = ActionController::API
end

class HelloController < action_controller_api_class
  def world
    render json: {hello: :world}
  end
end

App.initialize!

Rack::Server.new(app: App, Host: '0.0.0.0', Port: 3000).start
