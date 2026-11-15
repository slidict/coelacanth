FROM ruby:3.4-bookworm

WORKDIR /app

RUN apt-get update -qq && apt-get install -y git
COPY . .
RUN bundle install

# Root at start so the entrypoint can create the user and hand over the bundle
# path; it drops to that user before running the command.
#
# chmod in its own RUN rather than `COPY --chmod`, which needs BuildKit: this
# repository is developed on Windows, where the file's mode bit does not survive
# the checkout, and a legacy builder would silently copy it unexecutable.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
