# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.2.7

# --- Build stage ---
FROM ruby:${RUBY_VERSION}-slim AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      libyaml-dev \
      git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v "$(grep -A1 'BUNDLED WITH' Gemfile.lock | tail -1 | tr -d ' ')" && \
    bundle config set --local deployment true && \
    bundle config set --local without "development test" && \
    bundle install --jobs 4 && \
    rm -rf ~/.bundle/cache vendor/bundle/ruby/*/cache

COPY . .

RUN bundle exec bootsnap precompile --gemfile app/ lib/

# --- Production stage ---
FROM ruby:${RUBY_VERSION}-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      libpq5 \
      curl && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

WORKDIR /app

COPY --from=build --chown=rails:rails /app /app
COPY --from=build /usr/local/bundle /usr/local/bundle

USER rails:rails

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
