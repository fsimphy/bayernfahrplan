#!/bin/bash
set -ev

if [ "${BUILD_TYPE}" = "debug" ]; then
  dub build --override-config vibe-d:tls/openssl --compiler=${DC}
fi

if [ "${BUILD_TYPE}" = "unittest" ]; then
  dub test --override-config vibe-d:tls/openssl --compiler=${DC} -- -s
fi

if [ "${BUILD_TYPE}" = "unittest-cov" ]; then
  dub test --coverage --override-config vibe-d:tls/openssl --compiler=${DC} -- -s
  bash <(curl -s https://codecov.io/bash)
fi
