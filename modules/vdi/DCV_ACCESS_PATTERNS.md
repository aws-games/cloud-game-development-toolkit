# VDI Access Patterns - Windows DCV Architecture

## Windows DCV Limitation
**Windows DCV supports only 1 console session per instance.** This is an architectural constraint, not a configuration issue.

## Access Methods

### 1. **Primary User Access - DCV Session**
- **Method**: DCV web client or native client
- **URL**: `https://<instance-ip>:8443`
- **Session**: `<username>-session` (e.g., `john-doe-session`)
- **Owner**: Assigned user (e.g., `john-doe`)
- **Use Case**: Primary desktop access for end users

### 2. **Admin Collaboration - Join DCV Session**
- **Method**: Same DCV client, same session ID
- **URL**: `https://<instance-ip>:8443#<username>-session`
- **Access**: Admins can join the user's session
- **Use Case**: Support, troubleshooting, collaboration
- **Permissions**: Configured via `default.pv` file

### 3. **Independent Admin Access - RDP**
- **Method**: RDP client
- **Endpoint**: `<instance-ip>:3389`
- **Accounts**: `Administrator` or `VDIAdmin`
- **Use Case**: Independent admin work, system maintenance
- **Authentication**: EC2 key pair or Secrets Manager

## Terraform Implementation

### SSM Document Strategy
```yaml
# Creates single shared DCV session
# Configures session sharing permissions
# Admins can join user session or use RDP independently
```

### Connection Outputs
```hcl
dcv_endpoint = "https://3.230.145.120:8443"
dcv_session_name = "john-doe-session"
dcv_access_note = "Shared session - admins can join, user owns session"

rdp_endpoint = "3.230.145.120:3389"  
rdp_access_note = "Use for independent admin work"
```

## Usage Scenarios

### Scenario 1: Normal User Work
1. User connects to DCV session: `https://ip:8443#john-doe-session`
2. User works independently in their desktop

### Scenario 2: Admin Support
1. User is already connected to DCV session
2. Admin joins same session: `https://ip:8443#john-doe-session`
3. Admin can see user's screen and take control
4. Admin disconnects when done

### Scenario 3: Independent Admin Work
1. Admin connects via RDP: `ip:3389`
2. Admin logs in as `Administrator` or `VDIAdmin`
3. Admin has independent desktop session
4. User's DCV session continues unaffected

## Migration from Multi-Session Approach

### Before (Attempted)
- Multiple independent DCV sessions ❌
- Administrator session + VDIAdmin session ❌
- Not possible on Windows DCV

### After (Working)
- Single shared DCV session ✅
- RDP for independent admin access ✅
- Follows Windows DCV architecture ✅

## Security Considerations

### DCV Session Sharing
- Configured via `default.pv` permissions file
- Only specified users can join sessions
- Session owner maintains primary control

### RDP Access
- Separate authentication (EC2 keys/Secrets Manager)
- Independent of DCV session
- Standard Windows RDP security model

## Alternative Architectures

### For True Multi-User VDI
1. **Amazon WorkSpaces** - Managed VDI service
2. **Linux DCV** - Supports virtual sessions
3. **Multiple Windows instances** - One per user
4. **Amazon AppStream 2.0** - Application streaming

### Current Architecture Benefits
- ✅ Cost-effective (single instance)
- ✅ Collaborative support capability
- ✅ Independent admin access
- ✅ Works with Windows DCV limitations
- ✅ Terraform-managed and reproducible