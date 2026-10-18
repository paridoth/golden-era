#!/bin/sh
GE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$GE_ROOT/start.sh" "$@"
