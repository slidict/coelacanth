FROM slidict/docker-rails:latest

ARG UID

RUN if [ "$UID" -ne "" ] ; then \
      useradd user -d /app -u $UID; \
    fi

RUN apt-get update -qq \
    && apt-get install -y git ruby-full \
    && gem install bundler
COPY . .
RUN bundle install
