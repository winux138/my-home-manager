#!/usr/bin/env sh

column -t -s '|' -o '|' | sed -e :a -e 's/\(-[[:space:]]*\)[[:space:]]/\1-/g; ta'
