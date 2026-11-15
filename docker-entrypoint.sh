#!/bin/sh
# Run the command as a user whose UID matches the host owner of the bind-mounted
# /app, so files written through the mount are not left root-owned.
#
# A build-time USER cannot do this: it cannot be conditional, and the UID has to
# match whichever host mounted the checkout, which is not known at build time.
set -e

bundle_path="${BUNDLE_PATH:-/usr/local/bundle}"

# Everything below needs root: useradd, groupadd, chown and setpriv all do.
# `docker compose run --user ...`, or a `user:` on the service, starts the
# container as that user already, which is the outcome this script exists to
# produce, so there is nothing left to do.
if [ "$(id -u)" != 0 ]; then
  exec "$@"
fi

# `UID` is an explicit override. Without it the owner of the mount is exactly the
# UID that needs matching, so no setup is required on the developer's side. The
# group is read from the mount too, so files written through it carry a group that
# means something on the host rather than one invented in the container.
target="${UID:-}"
target_gid=""
if [ -z "$target" ] && [ -d /app ]; then
  target=$(stat -c %u /app)
  target_gid=$(stat -c %g /app)
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
case "$target_gid" in
  "") ;;
  *[!0-9]*)
    echo "docker-entrypoint.sh: GID must be numeric, got '$target_gid'" >&2
    exit 1
    ;;
esac

# The names carry the ids rather than being a fixed `app`. A fixed name collides
# as soon as something already holds it under a different id -- another entrypoint
# run in the same container, or an account the base image ships -- and useradd and
# groupadd fail on the name, which `set -e` turns into a container that will not
# start.
name=$(getent passwd "$target" | cut -d: -f1)
if [ -z "$name" ]; then
  name=container-$target
  if [ -n "$target_gid" ] && ! getent group "$target_gid" > /dev/null; then
    groupadd --gid "$target_gid" "container-$target_gid"
  fi
  if [ -n "$target_gid" ]; then
    useradd --uid "$target" --gid "$target_gid" --create-home --shell /bin/bash "$name"
  else
    useradd --uid "$target" --create-home --shell /bin/bash "$name"
  fi
fi

# `useradd --create-home` only ran for a UID that was unknown. A UID matching a
# system account in the base image brings that account's home instead, which is
# not usable: uid 100 owns /nonexistent and uid 1 owns a root-owned /usr/sbin.
# Such a user gets a home of its own rather than having a system directory
# chowned out from under the image. Ownership, not `-w`, decides: this runs as
# root, which reports every directory writable.
home=$(getent passwd "$target" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ] || [ "$(stat -c %u "$home")" != "$target" ]; then
  home=/home/container-$target
  mkdir -p "$home"
  chown "$target" "$home"
fi

# Gems were installed as root at build time. `bundle exec` only reads this, but
# `bundle install` inside the container has to write to it.
chown -R "$target" "$bundle_path"

# setpriv keeps the environment, so HOME would still point at root's unwritable
# home and Bundler would fall back to a temporary one.
HOME="$home"
export HOME

exec setpriv --reuid "$target" --regid "$(id -g "$name")" --init-groups "$@"
