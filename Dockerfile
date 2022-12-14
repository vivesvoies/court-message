FROM ruby:3.1.3

LABEL maintainer="ljt@meidosem.com"

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    vim

WORKDIR /usr/src/cm/

COPY Gemfile* /usr/src/cm/
ENV BUNDLE_PATH /gems
RUN bundle install

COPY . /usr/src/cm/

ENTRYPOINT ["./bin/docker-entrypoint"]

CMD ["bin/run"]