ARG RUBY_VERSION

FROM ruby:${RUBY_VERSION}

# bash: for consistency
# tzdata: rails
# gcompat: nokogiri & al.
#   Error loading shared library ld-linux-x86-64.so.2: No such file or directory
#   Error loading shared library ld-linux-aarch64.so.1: No such file or directory
RUN if [ -f /etc/alpine-release ]; then apk add build-base bash tzdata && if ! grep -e '^3\.8' /etc/alpine-release; then apk add gcompat; fi; fi

RUN <<-SHELL
      case ${RUBY_VERSION} in
      2.1*|2.2*)
         gem update --system '2.7.11'
         gem install bundler -v '~> 1.17.3'
         ;;
      2.3*|2.4*)
         # rails 4.1 and 4.2 need bundler < 2.0
         gem update --system '2.7.11'
         gem install bundler -v '~> 1.17.3'
         ;;
      2.5*)
         gem update --system '3.3.27'
         gem install bundler -v '~> 2.3.27'
         ;;
      2.6*|2.7*)
         gem update --system '3.4.22'
         gem install bundler -v '~> 2.4.22'
         ;;
      *)
         gem update --system
         gem install bundler
         ;;
    esac
SHELL
