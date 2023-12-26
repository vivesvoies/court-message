FROM ruby:3.3.0-slim

LABEL maintainer="ljt@meidosem.com"

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    build-essential \
    ruby-dev \
    libjemalloc2 \
    libpq-dev \
    vim \
    git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LD_PRELOAD=libjemalloc.so.2

WORKDIR /usr/src/cm/

ENV BUNDLE_PATH /gems
COPY Gemfile* /usr/src/cm/
RUN bundle install

COPY . /usr/src/cm/

ENTRYPOINT ["./bin/docker-entrypoint"]

CMD ["bin/run"]
