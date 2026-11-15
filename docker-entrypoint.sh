#!/bin/sh
# Run the command as a user whose UID matches the host owner of the bind-mounted
# /app, so files written through the mount are not left root-owned.
#
# A build-time USER cannot do this: it cannot be conditional, and the UID has to
# match whichever host mounted the checkout, which is not known at build time.
set -e

bundle_path="${BUNDLE_PATH:-/usr/local/bundle}"

# `UID` is an explicit override. Without it, the owner of the mount is exactly the
# UID that needs matching, so no setup is required on the developer's side.
target="${UID:-}"
if [ -z "$target" ] && [ -d /app ]; then
  target=$(stat -c %u /app)
fi

# Empty or 0 means run as root, unchanged from before. That covers Windows hosts,
# where there is no host UID to match, and a plain `docker run` with no mount.
if [ -z "$target" ] || [ "$target" = 0 ]; then
  exec "$@"
fi

case "$target" in
  *[!0-9]*)
    echo "docker-entrypoint.sh: UID must be numeric, got '$target'" >&2
    exit 1
    ;;
esac

name=$(getent passwd "$target" | cut -d: -f1)
if [ -z "$name" ]; then
  name=app
  useradd --uid "$target" --create-home --shell /bin/bash "$name"
fi

# Gems were installed as root at build time. `bundle exec` only reads this, but
# `bundle install` inside the container has to write to it.
chown -R "$target" "$bundle_path"

# setpriv keeps the environment, so HOME would still point at root's unwritable
# home and Bundler would fall back to a temporary one.
HOME=$(getent passwd "$target" | cut -d: -f6)
export HOME

exec setpriv --reuid "$target" --regid "$(id -g "$name")" --init-groups "$@"
