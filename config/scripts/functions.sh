#!/bin/bash
terraform_init () {
    terraform --version

    terraform init -input=false -no-color

    terraform workspace select -or-create=true ${WORKSPACE:-default} 
}

terraform_plan () {
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
        check_tfplan
        echo "Saving human-readable plan output to tfplan.txt..."
        terraform show -no-color tfplan > tfplan.txt
        EXIT_CODE=0
    else
        echo "Error running terraform plan."
    fi

    return $EXIT_CODE
}

terraform_apply () {
    terraform apply -input=false -no-color tfplan
    [ -f tfplan ] && rm tfplan
    [ -f tfplan.json ] && rm tfplan.json
    [ -f tfplan.txt ] && rm tfplan.txt
}

check_tfplan () {
    if [ -f tfplan ]; then
        echo "Check plan with trivy..."
        trivy fs --skip-version-check --scanners misconfig,secret -f json -o plan.json tfplan
    else
        echo "No tfplan file found."
    fi
}

check_terraform () {
    EXIT_CODE=0

    echo "Check format..."
    if ! terraform fmt -check -recursive -no-color; then
        echo "terraform fmt failed."
        EXIT_CODE=1
    fi

    echo "Check terraform files with trivy..."
    if ! trivy fs --skip-version-check --scanners misconfig,secret -f json -o source.json .; then
        echo "trivy scan of terraform files failed."
        EXIT_CODE=1
    fi

    echo "Check terraform files with tflint..."
    if ! tflint --init; then
        echo "tflint --init failed."
        EXIT_CODE=1
    fi
    if ! tflint --recursive --format json --config "$DEVBOX_PROJECT_ROOT/.devbox/virtenv/terraform-cicd/.tflint.hcl"; then
        echo "tflint scan of terraform files failed."
        EXIT_CODE=1
    fi

    if [ -f README.md ]; then
        echo "Running terraform-docs..."
        if ! terraform-docs markdown table --output-file README.md --output-mode inject .; then
            echo "terraform-docs failed."
            EXIT_CODE=1
        fi
    else
        echo "README.md does not exist, skipping terraform-docs."
    fi

    return $EXIT_CODE
}

check () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform_init

    check_terraform

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}

plan () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform_init

    set +e
    terraform_plan
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
        terraform_init

        terraform_apply
    else
        echo "No tfplan file found. Please run 'devbox run plan' first."
        exit 1
    fi

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}

plan-and-apply () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform_init

    set +e
    terraform_plan
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
            terraform_apply
        else
            echo "Terraform Plan not applied."
        fi
    fi
    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}

test () {
    pushd "$WORKDIR" || { echo "Failed to change directory to '$WORKDIR'."; exit 1; }

    terraform_init

    terraform validate -no-color

    terraform test -no-color

    popd || { echo "Failed to change directory back from '$WORKDIR'."; exit 1; }
}