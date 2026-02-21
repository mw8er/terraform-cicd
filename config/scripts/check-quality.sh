#!/bin/bash

set -euo pipefail

. "$DEVBOX_PROJECT_ROOT/.devbox/virtenv/terraform-cicd/functions.sh"

check-quality

