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

# An ENTRYPOINT with no CMD makes `docker run` with no command pass an empty
# argument list to the script, which would exit 0 having done nothing on the root
# path and fail inside setpriv on the other. Compose always supplies its own
# `command`, so this only covers the bare `docker run`.
CMD ["bash"]
