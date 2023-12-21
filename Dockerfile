FROM ghcr.io/moritzheiber/ruby-jemalloc:3.2.2-slim

LABEL maintainer="ljt@meidosem.com"

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    libpq-dev \
    vim \
    git

WORKDIR /usr/src/cm/

COPY Gemfile* /usr/src/cm/
ENV BUNDLE_PATH /gems
RUN bundle install

COPY . /usr/src/cm/

ENTRYPOINT ["./bin/docker-entrypoint"]

CMD ["bin/run"]
