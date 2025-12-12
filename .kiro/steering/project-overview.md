# Cloud Game Development Toolkit - Project Overview

## About

The **Cloud Game Development Toolkit (CGD Toolkit)** is a collection of Terraform modules, scripts, and configurations for deploying game development infrastructure and tools on AWS.

## Project Structure

```
cloud-game-development-toolkit/
├── assets/              # Reusable scripts, Packer templates, Ansible playbooks
├── modules/             # Terraform modules for game dev infrastructure
│   ├── jenkins/        # Jenkins CI/CD infrastructure
│   ├── perforce/       # Perforce version control
│   ├── teamcity/       # TeamCity CI/CD infrastructure
│   ├── unity/          # Unity-specific tools
│   ├── unreal/         # Unreal Engine tools (Horde, Cloud DDC)
│   └── vdi/            # Virtual desktop infrastructure
├── samples/            # Complete Terraform configurations
└── docs/               # Documentation source
```

## Key Technologies

- **Terraform**: Infrastructure as Code (IaC)
- **AWS**: Cloud infrastructure provider
- **Packer**: Machine image building
- **Ansible**: Configuration management
- **Docker**: Container images

## Design Philosophy

### 1. Modularity and Flexibility
Modules are building blocks, not complete solutions. Users compose modules to fit their needs.

### 2. Conservative Variable Exposure
Start with minimal variables. Add based on user demand. Default values work for 80% of use cases.

### 3. Security by Default
- No `0.0.0.0/0` ingress rules in module code
- Private-first architecture
- HTTPS enforcement for internet-facing services
- User-controlled security groups

### 4. Readability First
- Explicit over implicit configurations
- Descriptive variable names
- Self-documenting code
- Comment complex logic with business context

## Key Documentation

- **Design Standards**: `modules/DESIGN_STANDARDS.md`
- **Contributing**: `CONTRIBUTING.md`
- **Documentation**: https://aws-games.github.io/cloud-game-development-toolkit/
