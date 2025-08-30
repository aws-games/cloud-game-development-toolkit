# Unreal Cloud DDC Monitoring

This submodule deploys monitoring infrastructure for ScyllaDB using Prometheus, Grafana, and Alertmanager.

## Components

- **EC2 Instance**: Dedicated monitoring server
- **ScyllaDB Monitoring Stack**: Prometheus, Grafana, Alertmanager
- **Application Load Balancer**: HTTPS access to Grafana dashboard
- **Security Groups**: Network access controls for monitoring

## Usage

This submodule is part of the main Unreal Cloud DDC module. For complete documentation, see the [main module](../../README.md).

## Features

- **ScyllaDB Metrics**: Database performance and health monitoring
- **Grafana Dashboards**: Pre-configured visualizations for DDC metrics
- **Alerting**: Prometheus alerts for critical ScyllaDB issues
- **HTTPS Access**: Secure web interface via Application Load Balancer

## Configuration

Key variables:

- `scylla_monitoring_instance_type`: EC2 instance type for monitoring server
- `create_application_load_balancer`: Enable ALB for Grafana access
- `monitoring_application_load_balancer_subnets`: Public subnets for ALB

<!-- BEGIN_TF_DOCS -->
