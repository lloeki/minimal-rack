def resolve_args(args)
  require 'yaml'

  compatibility = YAML.load(File.read('compatibility'))
  a = args.to_a

  filename = nil
  ruby_image = nil
  while (arg = a.shift)
    candidate = File.basename(arg, '.rb')

    if (c = compatibility[candidate.split(':')[0]])
      kind = candidate.split(':')[0]
      version = candidate.split(':')[1] # TODO: nil?
      compatibility_match = c.select do |e|
        # TODO: corner cases
        # does not match on 3 if only ~> 3.2, e.g rails
        # matches on 4 if ~> 4.0 and ~> 4.2 but will resolve to 4.2 but with 4.0 compat match (wrong ruby, wrong gem...)
        Gem::Requirement.new(e['version']).satisfied_by?(Gem::Version.new(version))
      end.tap do |m|
        if m.empty?
          raise ArgumentError, "unmatched requirement for #{kind}:#{version}"
        elsif !m.one?
          raise ArgumentError, "ambiguous version range for #{kind}:#{version}"
        end
      end.first
    elsif candidate =~ /^(\d+\.\d+(?:\.\d+|))$/
      ruby_version = $1
      ruby_libc = 'gnu'
    elsif candidate =~ /^(\d+\.\d+(?:\.\d+|))-alpine$/
      ruby_version = $1
      ruby_libc = 'musl'
    elsif %w[x86_64 aarch64].include?(candidate)
      ruby_cpu = candidate
    elsif %w[musl alpine].include?(candidate)
      ruby_libc = 'musl'
    elsif %w[gnu debian].include?(candidate)
      ruby_libc = 'gnu'
    elsif %w[puma unicorn rainbows thin falcon webrick].include?(candidate)
      server = candidate
    else
      raise ArgumentError, "unsupported arg: #{arg}"
    end
  end

  if server.nil?
    server = 'thin'
  end

  if kind.nil?
    if ruby_version.nil?
      kind = compatibility.keys.first # TODO: pick a better one than .first
      compatibility_match = compatibility[kind].first # TODO: pick a better one than .first
      # TODO: get kind version (for serve), like having kind specified but versionless
    else
      match = compatibility.each_with_object([]) do |(k, c), m|
        version_matches = c.select do |e|
          Gem::Requirement.new(e['ruby']).satisfied_by?(Gem::Version.new(ruby_version))
        end

        m << [k, version_matches] if version_matches.any?
      end.first # TODO: pick a better one than .first

      if match.nil?
        raise ArgumentError, "unmatched requirement for ruby:#{ruby_version}"
      end

      compatibility_match = match[1].first # TODO: pick a better one than .first
      # TODO: get kind version (for serve), like having kind specified but versionless
      kind = match[0]
    end
  end

  if filename.nil?
    filename = compatibility_match['main'] || kind + '.rb'
  end

  if ruby_version.nil?
    match = %w[2.1 2.2 2.3 2.4 2.5 2.6 2.7 3.0 3.1 3.2 3.3].map { |v| Gem::Version.new(v) }.select do |v|
      Gem::Requirement.new(compatibility_match['ruby']).satisfied_by?(v)
    end.max

    if match.nil?
      raise ArgumentError, "unmatched requirement for ruby with #{kind}:#{version}"
    end

    ruby_version = match.to_s
  end

  if ruby_cpu.nil?
    if RUBY_PLATFORM =~ /^(?:universal\.|)(x86_64|aarch64|arm64)/
      ruby_cpu = $1.sub(/arm64(:?e|)/, 'aarch64')
    else
      raise ArgumentError, "unsupported platform: #{RUBY_PLATFORM}"
    end
  end

  ruby_os = 'linux'

  if ruby_libc.nil?
    ruby_libc = 'gnu'
  end

  ruby_platform = "#{ruby_cpu}-#{ruby_os}-#{ruby_libc}"

  if ruby_image.nil?
    if ruby_libc == 'musl'
      ruby_image = ruby_version + '-alpine'
    else
      ruby_image = ruby_version
    end
  end

  {
    version: version,
    ruby_image: ruby_image,
    ruby_version: ruby_version,
    filename: filename,
    server: server,
    ruby_platform: ruby_platform,
  }.tap { |r| p r }
end

def satisfied?(result, deps = [])
  result_time = case result
                when String
                  File.ctime(result).to_datetime
                when Proc
                  result.call
                else
                  raise ArgumentError, "invalid type: #{dep.class}"
                end

  return false if result_time.nil?
  return true if deps.empty?

  deps.map do |dep|
    dep_time = case dep
               when String
                 File.ctime(dep).to_datetime
               when Proc
                 dep.call
               else
                 raise ArgumentError, "invalid type: #{dep.class}"
               end

    result_time > dep_time
  end.reduce(:&)
end

namespace :docker do
  def image(env)
    "sandbox/minimal:ruby-#{env[:ruby_image]}"
  end

  def volume(env)
    "sandbox-minimal-ruby-#{env[:ruby_image]}-#{env[:ruby_platform]}"
  end

  def docker_platform(env)
    env[:ruby_platform].split('-').take(2).reverse.join('/')
  end

  def image_time(image)
    require 'time'

    last_tag_time = `docker image inspect -f '{{ .Metadata.LastTagTime }}' '#{image}'`.chomp

    if $?.to_i == 0
      DateTime.strptime(last_tag_time, '%Y-%m-%d %H:%M:%S.%N %z')
    else
      nil
    end
  end

  def volume_time(volume)
    require 'time'

    volume_creation_time = `docker volume inspect -f '{{ .CreatedAt }}' '#{volume}'`.chomp

    if $?.to_i == 0
      DateTime.strptime(volume_creation_time, '%Y-%m-%dT%H:%M:%S%z')
    else
      nil
    end
  end

  namespace :image do
    task :build do |_task, args|
      env = resolve_args(args)

      deps = [
        'Dockerfile'
      ]

      next if satisfied?(-> { image_time(image(env)) }, deps)

      sh "docker buildx build --platform #{docker_platform(env)} -f Dockerfile --build-arg RUBY_VERSION='#{env[:ruby_image]}' --tag '#{image(env)}' ."
    end

    task :clean do |_task, args|
      env = resolve_args(args)

      sh "docker image rm '#{image(env)}'"
    end
  end

  namespace :volume do
    task :create do |_task, args|
      env = resolve_args(args)

      next if satisfied?(-> () { volume_time(volume(env))} )

      sh "docker volume create #{volume(env)}"
    end

    task :clean do |_task, args|
      env = resolve_args(args)

      sh "docker volume rm '#{volume(env)}'"
    end
  end

  task :build => :'docker:image:build'
  task :volume => :'docker:volume:create'

  task :ruby => [:build, :volume] do |_task, args|
    env = resolve_args(args)

    sh "docker run --rm -it --platform #{docker_platform(env)} -v '#{volume(env)}':'/usr/local/bundle' -v '#{Dir.pwd}':'#{Dir.pwd}' -w '#{Dir.pwd}' '#{image(env)}'"
  end

  task :shell => [:build, :volume] do |_task, args|
    env = resolve_args(args)

    sh "docker run --rm -it --platform #{docker_platform(env)} -v '#{volume(env)}':'/usr/local/bundle' -v '#{Dir.pwd}':'#{Dir.pwd}' -w '#{Dir.pwd}' '#{image(env)}' /bin/bash"
  end

  task :serve => [:build, :volume] do |_task, args|
    env = resolve_args(args)

    sh "docker run --rm -it --platform #{docker_platform(env)} -v '#{volume(env)}':'/usr/local/bundle' -v '#{Dir.pwd}':'#{Dir.pwd}' -w '#{Dir.pwd}' -p 3000:3000 '#{image(env)}' ruby '#{env[:filename]}' '#{env[:version]}' '#{env[:server]}'"
  end
end
