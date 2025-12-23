# Unreal Engine BuildGraph ONTAP Integration

Custom BuildGraph tasks for integrating Perforce syncing with NetApp ONTAP FlexClone operations.

## Files

**Tasks/** - C# BuildGraph task implementations
- `SyncAndSnapshotTask.cs` - Sync from Perforce and create ONTAP snapshot
- `CloneVolumeTask.cs` - Create FlexClone volume from snapshot
- `DeleteVolumeTask.cs` - Delete ONTAP volume
- `DeleteSnapshotTask.cs` - Delete ONTAP snapshot

**AutomationUtils/** - Helper utilities
- `OntapUtils.cs` - ONTAP REST API operations and AWS Secrets Manager integration

**Examples/** - BuildGraph XML workflows
- `SyncAndSnapshotExample.xml` - Sync from Perforce and snapshot
- `CloneVolumeExample.xml` - Create FlexClone from snapshot
- `DeleteVolumeExample.xml` - Delete clone and snapshot

## Prerequisites

- AWS CLI configured with credentials
- Perforce client (p4)
- AWS Secrets Manager secret containing FSx ONTAP password
- FSx ONTAP file system with SVM configured

## Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `FsxAdminIp` | FSx ONTAP management IP | - |
| `OntapUser` | ONTAP username | fsxadmin |
| `OntapPasswordSecretName` | AWS secret name for ONTAP password | - |
| `AwsRegion` | AWS region | us-east-1 |
| `SvmName` | Storage Virtual Machine name | fsx |

## Notes

- Snapshot deletion may fail immediately after clone deletion due to ONTAP lock timing
- FlexClone volumes are full read/write volumes with instant creation
- AWS Secrets Manager password retrieval is handled automatically by OntapUtils class
- All ONTAP operations use REST API over HTTPS (self-signed certificates accepted)
