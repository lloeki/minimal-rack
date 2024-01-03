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

  gem 'grape', "~> #{version}.0"
  gem server

  match.fetch('gem', []).each do |name, requirement|
    gem name, requirement
  end
end

require 'rack'
require 'grape'

class API < Grape::API
  version 'v0', using: :header, vendor: 'hello'
  format :json
  prefix :hello

  get :world do
    { hello: 'world' }
  end

  #resource :hello do
  #  route_param :id do
  #    get do
  #      { hello: 'world' }
  #    end
  #  end
  #end

  # mount API::Sub
  # mount API::V1 => '/v1'
end

App = Rack::Builder.new do
  # precompile routes
  API.compile!

  run API

  # sinatra:
  # use Rack::Session::Cookie
  # run Rack::Cascade.new [Web, API]
end

Rack::Server.new(app: App, Host: '0.0.0.0', Port: 3000).start

