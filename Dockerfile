FROM ruby:3.4-bookworm

ARG UID

RUN if [ "$UID" -ne "" ] ; then \
      useradd user -d /app -u $UID; \
    fi

RUN apt-get update -qq && apt-get install -y git
WORKDIR /app

COPY . .
RUN bundle install
