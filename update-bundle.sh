#!/bin/sh -e
#
# Usage: ./update-bundles [DIRECTORY|GET_FILE]...
# Usage: env UPDATE_BUNDLES_SEQUENTIALLY=1 ./update-bundles
#
# Clones or updates the Git repositories specified in `./**/*.get` files,
# starting from the most recently modified file down to the earliest one,
# and then runs make(1) inside cloned directories that have a `Makefile`.
#
# This is done in parallel, at up to half of the maximum process limit,
# unless the `UPDATE_BUNDLES_SEQUENTIALLY` environment variable is set.
#
# Usage: ./update-bundles [DIRECTORY|GET_FILE]...
#
# Written in 2010 by Suraj N. Kurapati <https://github.com/sunaku>

parallel_processes=$(ulimit -a | awk '/process/ { print int( $NF / 2 ) }')

# add color to the output when stdout is connected to a terminal device
test -t 1 && colorize='
  s/.* Already up-to-date\.$/\x1b[34m&\x1b[0m/        # blue
  s/.* Updating .*\.\..*/\x1b[32m&\x1b[0m/            # green
  s/.* Frozen at commit .*/\x1b[33m&\x1b[0m/          # yellow
  s/.* Failed with exit status .*/\x1b[31m&\x1b[0m/   # red
' || unset colorize

git ls-files -c -o "$@" | grep '\.get$' | xargs ls -t | { while read get; do

  url=$(cat "$get")
  dir=${get%.get}
  {
    {
      # XXX: The -e flag from the #! line up top does not take effect in this
      # backgrounded subshell for some reason.  Even an explicit `set -e` has
      # no effect!  So just work around this conundrum for now using exit $?.
      set -e

      mkdir -p "$dir"                                             || exit $?
      cd "$dir"                                                   || exit $?

      # clone or update the bundle as necessary
      if ! test -d .git; then
        git clone "$url" .                                        || exit $?
      elif git symbolic-ref -q HEAD >/dev/null; then
        git remote set-url origin "$url"                          || exit $?
        git fetch --quiet origin                                  || exit $?
        git merge --ff-only origin/master                         || exit $?
      else
        echo "Frozen at commit $(git show-ref -s7 HEAD)."
      fi

      # run user-defined commands after updating
      run=../${dir##*/}.run
      ref=.git/refs/heads/master
      if test -s "$run" -a "$run" -ot "$ref"; then
        sh -e "$run"                                              || exit $?
        touch "$run" -r "$ref"                                    || exit $?
      fi

    } </dev/null 2>&1 || echo "Failed with exit status $?."
  } | sed "s!^!$dir: !; $colorize" &

  test -n "$UPDATE_BUNDLES_SEQUENTIALLY" ||
  # throttle process creation to avoid exceeding system process limit
  # which results in "fork: Resource temporarily unavailable" errors
  test $(pgrep -u "$USER" | wc -l) -gt "$parallel_processes" && wait

done
wait
}
