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
  gem 'ddtrace', path: '../../Datadog/dd-trace-rb', require: 'ddtrace/auto_instrument'

  match.fetch('gem', []).each do |name, requirement|
    gem name, requirement
  end
end

require 'grape'

class GrapeAPI < Grape::API
  version 'v0', using: :header, vendor: 'hello'
  format :json
  prefix :hello

  get :world do
    { hello: 'grape' }
  end

  get '/:id' do
    { hello: params[:id] }
  end

  class Deeper < Grape::API
    get :world do
      { hello: 'deeper' }
    end

    get '/:id' do
      { hello: params[:id] }
    end
  end

  class Deep < Grape::API
    get :world do
      { hello: 'deep' }
    end

    get '/:id' do
      { hello: params[:id] }
    end

    mount Deeper => '/deeper'
  end

  mount Deep => '/deep'
end

require 'sinatra/base'
require 'json'

class SinatraApp < Sinatra::Base
  get '/hello/world' do
    status 200
    content_type :json
    body JSON.dump({ hello: :sinatra })
  end

  get '/hello/:id' do
    status 200
    content_type :json
    body JSON.dump({ hello: params[:id] })
  end
end

RackApp = Rack::Builder.new do
  map "/hello/world" do
    run -> (env) { [200, { 'content-type' => 'application/json' }, [JSON.dump({ hello: :rack })]] }
  end

  map "/grape" do
    run GrapeAPI.new
  end

  map "/sinatra" do
    run SinatraApp.new
  end

  map "/rack" do
    run -> (env) { RackApp.call(env) }
  end

  map "/engine/simple" do
    run -> (env) { SimpleEngine::Engine.call(env) }
  end

  map "/engine/endpoint" do
    run -> (env) { EndpointEngine::Engine.call(env) }
  end
end

require "action_controller/railtie"

module FindRootHack
    def find_root(from)
      Pathname.new File.realpath from
    end
end

module SimpleEngine
  class Engine < ::Rails::Engine
    extend FindRootHack

    routes.append do
      get "/hello/world" => "simple_engine/hello#world"
      get "/hello/:id" => "simple_engine/hello#world"
    end
  end

  class HelloController < ActionController::API
    def world
      render json: {hello: :engine}
    end
  end
end

module EndpointEngine
  class Engine < ::Rails::Engine
    extend FindRootHack

    endpoint RackApp
  end

  class HelloController < ActionController::API
    def world
      render json: {hello: params[:id] || :engine}
    end
  end
end

module SimpleApp
class App < Rails::Application
  routes.append do
    get "/hello/world" => "hello#world"
    get "/hello/:id" => "hello#world"

    mount SimpleEngine::Engine => "/engine/simple"
    mount EndpointEngine::Engine => "/engine/endpoint"
    mount RackApp => "/rack"
    mount SinatraApp => "/sinatra"
    mount GrapeAPI => "/grape"
  end

  config.consider_all_requests_local = true # display errors
  config.eager_load = true # load everything

  if Gem::Requirement.new('< 4.0').satisfied_by?(Gem.loaded_specs['rails'].version)
    config.secret_token = 'a4e6df27-2f39-41e4-83d2-3bc4d087c910'
  else
    config.secret_key_base = 'a4e6df27-2f39-41e4-83d2-3bc4d087c910'
  end
end
end

if Gem::Requirement.new('< 5.0').satisfied_by?(Gem.loaded_specs['rails'].version)
  action_controller_api_class = ActionController::Base
else
  action_controller_api_class = ActionController::API
end

class HelloController < action_controller_api_class
  def world
    render json: {hello: params[:id] || :rails}
  end
end

Datadog.configuration do |c|
  c.diagnostics.debug = ['true', '1'].include?(ENV['DD_DIAGNOSTICS'])
  c.tracing.enabled = true
  c.tracing.instrument :rack
  c.tracing.instrument :rails
  c.tracing.instrument :sinatra
  c.tracing.instrument :grape
end

SimpleApp::App.initialize!

Rack::Server.new(app: SimpleApp::App, Host: '0.0.0.0', Port: 3000).start
