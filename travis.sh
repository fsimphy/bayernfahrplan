#!/bin/bash
set -ev

if [ "${BUILD_TYPE}" = "debug" ]; then
  dub build --compiler=${DC}
fi

if [ "${BUILD_TYPE}" = "unittest" ]; then
  dub test --compiler=${DC}
fi

if [ "${BUILD_TYPE}" = "unittest-cov" ]; then
  dub test --coverage --compiler=${DC}
  bash <(curl -s https://codecov.io/bash)
fi
