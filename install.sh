#!/bin/bash

set -e
set -u

puts () {
  if [[ -t 1 ]]; then
    printf "%b>>>%b %b%s%b\n" "\x1b[1m\x1b[32m" "\x1b[0m" \
                              "\x1b[1m\x1b[37m" "$1" "\x1b[0m"
  else
    printf ">>> %s\n" "$1"
  fi
}

puts "\n $ ./update-bundle.sh"
(./update-bundle.sh)

puts "\n $ ./bootstrap/bootstrap.sh"
(./bootstrap/bootstrap/bootstrap.sh)

puts "\n$ ./dotbot.sh"
(./dotbot.sh)

exit
