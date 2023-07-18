#!/bin/bash

set -euo pipefail

print_usage () {
    cat << EOF

Usage:

    $0 [ENVIRONMENT] [FRONTEND_SERVICE_ACCOUNT_EMAIL]
EOF
}

if [ $# -lt 2 ]; then
    print_usage
    exit 1
fi

export ENVIRONMENT=$1
export FRONTEND_SERVICE_ACCOUNT_EMAIL=$2

# Switch to the directory where this script is located.
cd "$(dirname "${BASH_SOURCE[0]}")"

envsubst < "../../kubernetes/knative/overlays/$ENVIRONMENT/patch.yaml.dist" > "../../kubernetes/knative/overlays/$ENVIRONMENT/patch.yaml"
