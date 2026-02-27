#!/bin/bash

TRIVY_CONFIG=$TFCICD_CONFIG/trivy.yaml
TFLINT_CONFIG_FILE=$TFCICD_CONFIG/.tflint.hcl


terraform-init () {
    terraform --version

    terraform init

    terraform workspace select -or-create=true ${WORKSPACE:-default} 
}

terraform-plan () {
    echo "Running terraform validate..."
    terraform validate

    set +e
    terraform plan --detailed-exitcode -out tfplan
    EXIT_CODE=$?
    set -e
    if [ $EXIT_CODE -eq 0 ]; then
        echo "No changes to apply."
        [ -f tfplan ] && rm tfplan
    elif [ $EXIT_CODE -eq 2 ]; then
        check-tfplan
        echo "Saving human-readable plan output to tfplan.txt..."
        terraform show -no-color tfplan > tfplan.txt
        EXIT_CODE=0
    else
        echo "Error running terraform plan."
    fi

    return $EXIT_CODE
}

terraform-apply () {
    terraform apply tfplan
    [ -f tfplan ] && rm tfplan
    [ -f tfplan.json ] && rm tfplan.json
    [ -f tfplan.txt ] && rm tfplan.txt
}

check-tfplan () {
    if [ -f tfplan ]; then
        echo "Check plan with trivy..."
        trivy fs --skip-version-check --config $TRIVY_CONFIG --scanners misconfig,secret -f json -o trivy-plan-medium-low.json --exit-code 0 --severity MEDIUM,LOW tfplan
        trivy fs --skip-version-check --config $TRIVY_CONFIG --scanners misconfig,secret -f json -o trivy-plan-critical-high.json --exit-code 1 --severity HIGH,CRITICAL tfplan
    else
        echo "No tfplan file found."
    fi
}


check-terraform () {
    echo "Running terraform validate..."
    terraform validate

    USE_EXIT_CODE=1
    USE_FORCE=""

    echo "Check format..."
    local INTERACTIVE=${GITHUB_STATE:-interactive}
    if [ "$INTERACTIVE" == "interactive" ]; then
        echo "Formatting terraform files in interactive mode..."
        terraform fmt -recursive
        USE_EXIT_CODE=0
        USE_FORCE="--force"
    else
        echo "Check terraform file format in non-interactive mode..."
        terraform fmt -check -recursive
    fi

    echo "Check terraform files with trivy..."
    trivy fs --skip-version-check --config $TRIVY_CONFIG --scanners misconfig,secret -f json -o trivy-source-medium-low.json --exit-code 0 --severity MEDIUM,LOW .
    trivy fs --skip-version-check --config $TRIVY_CONFIG --scanners misconfig,secret -f json -o trivy-source-critical-high.json --exit-code $USE_EXIT_CODE --severity HIGH,CRITICAL .

    echo "Initializing tflint..."
    tflint --init --config $TFLINT_CONFIG_FILE
    echo "Check terraform files with tflint..."
    tflint --recursive --format json --config $TFLINT_CONFIG_FILE $USE_FORCE > tflint.json 
    echo ""

    if [ -f README.md ]; then
        echo "Running terraform-docs..."
        terraform-docs markdown table --output-file README.md --output-mode inject .
    else
        echo "README.md does not exist, skipping terraform-docs."
    fi
}

check-quality () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform-init

    check-terraform

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}

plan () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform-init

    set +e
    terraform-plan
    EXIT_CODE=$?
    set -e

    NEW_EXIT_CODE=0
    if [ $EXIT_CODE -eq 1 ]; then
        NEW_EXIT_CODE=$EXIT_CODE
    fi

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
    return $NEW_EXIT_CODE
}

apply () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    if [ -f tfplan ]; then
        terraform-init

        terraform-apply
    else
        echo "No tfplan file found. Please run 'devbox run plan' first."
        exit 1
    fi

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}

plan-and-apply () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform-init

    set +e
    terraform-plan
    set -e

    if [ -f tfplan ]; then
        approve="yes"
        local INTERACTIVE=${GITHUB_STATE:-interactive}
        if [ "$INTERACTIVE" == "interactive" ]; then
            read -p "Apply Terraform Plan? (yes/no): " -r approve
        fi
        if [[ "$approve" == "yes" ]]; then
            echo "Applying Terraform Plan..."
            terraform-apply
        else
            echo "Terraform Plan not applied."
        fi
    fi
    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}

test () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform-init

    terraform validate

    terraform test

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}
