ARG BASE_IMAGE=m.daocloud.io/docker.io/library/ruby:4.0.9-slim
FROM ${BASE_IMAGE}

# Aliyun mirror for apt in China
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG GEM_MIRROR=https://mirrors.aliyun.com/rubygems/
RUN gem sources --remove https://rubygems.org/ && \
    gem sources --add ${GEM_MIRROR} && \
    gem install rails -v 8.1.4.1 --no-document

WORKDIR /output
