#!/bin/bash
. /opt/spack/share/spack/setup-env.sh
spack env activate -v -d /home/pantheon
exec "$@"
