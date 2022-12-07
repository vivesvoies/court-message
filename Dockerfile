FROM ruby:3.1.3

LABEL maintener="ljt@meidosem.com"

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
    vim

WORKDIR /usr/src/cm/

COPY Gemfile* /usr/src/cm/
ENV BUNDLE_PATH /gems
RUN bundle install

COPY . /usr/src/cm/

CMD ["bin/rails", "s", "-b", "0.0.0.0"]