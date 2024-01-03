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

  gem 'rack', "~> #{version}.0"
  gem server

  match.fetch('gem', []).each do |name, requirement|
    gem name, requirement
  end
end

require 'rack'
require 'json'

App = Rack::Builder.new do
  map "/hello/world" do
    run -> (env) { [200, { 'content-type' => 'application/json' }, [JSON.dump({ hello: :world })]] }
  end
end

Rack::Server.new(app: App, Host: '0.0.0.0', Port: 3000).start
