ARG BASE_IMAGE=m.daocloud.io/docker.io/library/ruby:4.0.9-slim
FROM ${BASE_IMAGE} AS base

# Aliyun mirror for apt in China
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates curl libjemalloc2 sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV LD_PRELOAD="/usr/local/lib/libjemalloc.so"
ENV BUNDLE_PATH="/usr/local/bundle"

WORKDIR /plugin

# Development stage
FROM base AS development

ENV RAILS_ENV="development" \
    BUNDLE_DEPLOYMENT="" \
    BUNDLE_WITHOUT=""

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG GEM_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/rubygems/
COPY Gemfile Gemfile.lock demo_plugin.gemspec ./
COPY lib/demo_plugin/version.rb lib/demo_plugin/version.rb
RUN bundle config --global mirror.https://rubygems.org ${GEM_MIRROR} && \
    bundle install

COPY . .

# Test stage
FROM development AS test
ENV RAILS_ENV="test"
