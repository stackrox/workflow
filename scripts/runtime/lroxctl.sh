#! /bin/bash

if [[ -z "${ROX_API_TOKEN}" ]]; then
  roxctl --insecure-skip-tls-verify -e localhost:8000 -p $(gpp) $@
else
  roxctl --insecure-skip-tls-verify -e localhost:8000  $@
fi
