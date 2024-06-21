#!/bin/bash
set -e

readarray templates < <(yq -o=j -I=0 '.packer_templates[]' .config.yml) 

for template in "${templates[@]}"; do
  name=$(echo "$template" | yq '.name' -)
  path=$(echo "$template" | yq '.path' -)
  file_name=$(echo "$template" | yq '.file_name' -)
  echo "Validating packer template ${name}: ${path}${file_name}"
  cp ci.pkrvars.hcl "${path}/ci.pkrvars.hcl" # Move the variables file to the current directory
  pushd "${path}" > /dev/null # Change the current directory to the directory containing the packer template
  packer init "${file_name}" # Initialize the packer template
  packer validate -var-file=ci.pkrvars.hcl "${file_name}" # Validate the packer template
  status=$?
  if [ $status -ne 0 ]; then
    echo "Packer validation failed with status $status"
    exit $status
  fi
  popd > /dev/null # Change the current directory back to the original directory
done

