# minimal-rack

Minimal Rack-based apps for historical and toying purposes

This covers Rack, Rails, Sinatra, Grape, and possibly more Rack-based stuff in the future.

# Idea

Sometimes I want to toy around with specific versions of a framework on specific versions of Ruby or this or that web server, explore how versions behave, and Rack being Rack, what happens when you nest things and what you can and cannot nest.

Instead of hacking code for each version, manually changing Gemfiles back and forth, possibly using bad versions, or generating a thousand Rails apps, these profide a simple, compact, dynamic way to just get what I want and hack on the actual thing I want to learn about.

# Usage

* `compatibility` is a stupid YAML file with various version constraints.
* Native execution: `ruby {thing}.rb` serves `{thing}`. There is version resolution so `ruby rails.rb 7.0` gives you a Rails 7.0.something app, `ruby rails.rb 7.0.0` gives you exactly 7.0.0. There is server resolution too , so `ruby rails.rb 7.0 puma` serves with Puma.
* Docker execution: `rake:serve[rails]` gives you some rails, `:serve[rails:7.0]` gives you a Rails 7.0.something app like above, `rake:serve[rails,2.5]` gives you some rails version compatible with and running under ruby 2.5, give it `2.5-alpine` instead or add `musl` and it'll obey, and guess what you can shove `puma` or `thin` or whatever inside those brackets too.
* No bundler commands. There is bundler, but it's inline to dynamically describe deps, so, magic.

# Caveats

- There's a small issue with version selection vs how a thing version is specified in compatibility: if you say 'rails 7' it'll pick 7.1 but run with another compatibility match from a lesser version.
- There's no automatic web server picking (yet?), so it defaults to Thin but sometimes Thin doesn't work (e.g Rack 3)
