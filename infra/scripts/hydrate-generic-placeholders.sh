#!/bin/bash

set -euo pipefail

print_usage () {
    cat << EOF

Usage:

    $0 [GCP_PROJECT_ID]
EOF
}

if [ $# -lt 1 ]; then
    print_usage
    exit 1
fi

export GCP_PROJECT_ID=$1

# Switch to the directory where this script is located.
cd "$(dirname "${BASH_SOURCE[0]}")"

envsubst < "../../kubernetes/base/frontend.yaml.dist" > "../../kubernetes/base/frontend.yaml"
