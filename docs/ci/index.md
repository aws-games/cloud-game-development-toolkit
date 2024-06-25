# CI and Testing

This project uses Github Actions to automate continuous integration (CI) testing using utilities contained in the `.ci/` directories within the project's assets, modules, and samples. Dockerfiles are included to simplify running these CI workflows locally in your development environment or in a cloud CI environment. 

## Example CI directory: `packer/.ci/`

```shell
.ci/
├── Dockerfile <------------------ Dockerfile for running Packer CI
├── packer-validate.sh <---------- Script for linting with Packer Validate
├── README.md <------------------- Instructions for Packer CI
└── setup.sh <-------------------- Commands to setup environment (i.e install Packer)
```

