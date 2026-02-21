#!/bin/bash
terraform-init () {
    terraform --version

    terraform init -input=false -no-color

    terraform workspace select -or-create=true ${WORKSPACE:-default} 
}

terraform-plan () {
    echo "Running terraform validate..."
    terraform validate -no-color

    set +e
    terraform plan --detailed-exitcode -no-color -input=false -out tfplan
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
    terraform apply -input=false -no-color tfplan
    [ -f tfplan ] && rm tfplan
    [ -f tfplan.json ] && rm tfplan.json
    [ -f tfplan.txt ] && rm tfplan.txt
}

check-tfplan () {
    if [ -f tfplan ]; then
        echo "Check plan with trivy..."
        trivy fs --skip-version-check --scanners misconfig,secret -f json -o trivy-plan.json tfplan
    else
        echo "No tfplan file found."
    fi
}

check-terraform () {
    echo "Running terraform validate..."
    terraform validate -no-color

    echo "Check format..."
    terraform fmt -check -recursive -no-color

    echo "Check terraform files with trivy..."
    trivy fs --skip-version-check --scanners misconfig,secret -f json -o trivy-source-medium-low.json --exit-code 0 --severity MEDIUM,LOW .
    trivy fs --skip-version-check --scanners misconfig,secret -f json -o trivy-source-critical-high.json --exit-code 1 --severity HIGH,CRITICAL .

    echo "Initializing tflint..."
    tflint --init --config "$DEVBOX_PROJECT_ROOT/.devbox/virtenv/terraform-cicd/.tflint.hcl"
    echo "Check terraform files with tflint..."
    tflint --recursive --no-color --format json --config "$DEVBOX_PROJECT_ROOT/.devbox/virtenv/terraform-cicd/.tflint.hcl" > tflint.json 
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
        local AUTO_APPROVE=${AUTO_APPROVE:-false}
        local RESPONSE="no"
        if [[ "$AUTO_APPROVE" == "false" ]]; then
            if [ -t 0 ]; then
                read -p "Apply Terraform Plan? (yes/no): " -r RESPONSE
            else
                echo "Non-interactive environment detected and AUTO_APPROVE is false; skipping apply." >&2
            fi
        fi
        if [[ "$AUTO_APPROVE" == "true" ]] || [[ "$RESPONSE" == "yes" ]]; then
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

    terraform validate -no-color

    terraform test -no-color

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}