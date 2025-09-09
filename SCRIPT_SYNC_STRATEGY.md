# Script Synchronization Strategy

## Problem Statement

The VDI module has PowerShell scripts in two locations that must stay synchronized:

1. **Packer Templates**: `assets/packer/virtual-workstations/windows/*/base_setup_with_gpu_check.ps1`
2. **VDI Module**: `modules/vdi/scripts/base/base_setup_with_gpu_check.ps1`

**Risk**: These can drift over time, causing inconsistent AMI builds vs runtime behavior.

## Recommended Solution: Manual Synchronization (SHORT TERM)

### **Option 1: Keep Duplicates, Manual Sync (CURRENT)**

**Structure:**
```
modules/vdi/scripts/base/base_setup_with_gpu_check.ps1  ← VDI module version
assets/packer/.../base_setup_with_gpu_check.ps1         ← Standalone Packer version
```

**Process:**
1. Edit script in VDI module location
2. Manually copy to Packer locations
3. Test both VDI deployment and Packer build
4. Commit all changes together

**Benefits:**
- ✅ Packer templates work standalone (copy/paste friendly)
- ✅ VDI module works independently
- ✅ No complex relative paths
- ✅ Simple to understand and maintain

**Drawbacks:**
- ❌ Manual synchronization required
- ❌ Risk of forgetting to sync
- ❌ Potential for drift

### **Option 2: Future - Move Packer to Docs (LONG TERM)**

**Structure:**
```
modules/vdi/scripts/base/base_setup_with_gpu_check.ps1  ← Only location
docs/packer-examples/                                   ← Documentation only
```

**Implementation:**
- Remove `assets/packer/` directory entirely
- Add Packer examples to documentation
- Link to VDI module scripts in examples
- Users copy/modify as needed

**Benefits:**
- ✅ Single source of truth
- ✅ No synchronization needed
- ✅ Clear that Packer examples are reference only
- ✅ Reduces repository complexity

### **Option 3: Symbolic Links (NOT RECOMMENDED)**

**Structure:**
```
modules/vdi/scripts/base/base_setup_with_gpu_check.ps1  ← Source
assets/packer/.../base_setup_with_gpu_check.ps1        ← Symlink to source
```

**Implementation:**
```bash
# Create symlinks (run once)
cd assets/packer/virtual-workstations/windows/game-dev/
ln -sf ../../../../../modules/vdi/scripts/base/base_setup_with_gpu_check.ps1 .

cd ../lightweight/
ln -sf ../../../../../modules/vdi/scripts/base/base_setup_with_gpu_check.ps1 .
```

**Limitations:**
- ❌ Symlinks don't work well with Git on Windows
- ❌ Can break when repositories are cloned/moved
- ❌ Not supported in all environments

### **Option 3: Build-Time Copy (Complex)**

**Structure:**
```
modules/vdi/scripts/base/base_setup_with_gpu_check.ps1  ← Source
scripts/sync-packer-scripts.sh                         ← Sync script
assets/packer/.../base_setup_with_gpu_check.ps1        ← Generated (gitignored)
```

**Implementation:**
```bash
#!/bin/bash
# scripts/sync-packer-scripts.sh
cp modules/vdi/scripts/base/base_setup_with_gpu_check.ps1 assets/packer/virtual-workstations/windows/game-dev/
cp modules/vdi/scripts/base/base_setup_with_gpu_check.ps1 assets/packer/virtual-workstations/windows/lightweight/
```

**Limitations:**
- ❌ Requires manual execution before Packer builds
- ❌ Easy to forget sync step
- ❌ More complex CI/CD pipeline

## Implementation Plan

### **Phase 1: Manual Synchronization Process (IMMEDIATE)**

**When modifying scripts:**

1. **Edit source**: Modify `modules/vdi/scripts/base/base_setup_with_gpu_check.ps1`
2. **Copy to Packer locations**:
   ```bash
   cp modules/vdi/scripts/base/base_setup_with_gpu_check.ps1 assets/packer/virtual-workstations/windows/game-dev/
   cp modules/vdi/scripts/base/base_setup_with_gpu_check.ps1 assets/packer/virtual-workstations/windows/lightweight/
   ```
3. **Test both**: VDI deployment AND Packer build
4. **Commit together**: All three files in same commit

### **Phase 2: Add Sync Validation (SAFETY NET)**

**Pre-commit hook to check synchronization:**
```bash
#!/bin/bash
# Check if scripts are synchronized
VDI_SCRIPT="modules/vdi/scripts/base/base_setup_with_gpu_check.ps1"
PACKER_GAME_DEV="assets/packer/virtual-workstations/windows/game-dev/base_setup_with_gpu_check.ps1"
PACKER_LIGHTWEIGHT="assets/packer/virtual-workstations/windows/lightweight/base_setup_with_gpu_check.ps1"

if ! diff -q "$VDI_SCRIPT" "$PACKER_GAME_DEV" >/dev/null 2>&1; then
    echo "ERROR: VDI and Packer game-dev scripts are out of sync"
    exit 1
fi

if ! diff -q "$VDI_SCRIPT" "$PACKER_LIGHTWEIGHT" >/dev/null 2>&1; then
    echo "ERROR: VDI and Packer lightweight scripts are out of sync"
    exit 1
fi
```

### **Phase 3: Update Documentation (GUIDANCE)**

Update Packer README files to explain synchronization:

```markdown
## Script Management

**IMPORTANT**: Scripts are duplicated between VDI module and Packer templates for standalone usage.

**Primary Location**: `modules/vdi/scripts/base/base_setup_with_gpu_check.ps1`
**Packer Copies**: `assets/packer/.../base_setup_with_gpu_check.ps1`

**To modify scripts**:
1. Edit the script in `modules/vdi/scripts/base/`
2. Copy to both Packer template directories
3. Test VDI deployment AND Packer build
4. Commit all changes together

**CRITICAL**: Keep all three copies synchronized manually.
```

### **Phase 4: Future - Consolidate to Docs (LONG TERM)**

**When ready to simplify**:
1. Move Packer templates to `docs/examples/packer/`
2. Remove `assets/packer/` directory
3. Update documentation to reference VDI module scripts
4. Accept that users need to copy/modify for standalone use

## Validation Strategy

### **Pre-commit Hook (Recommended)**

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check for duplicate base_setup scripts
PACKER_SCRIPTS=$(find assets/packer -name "base_setup_with_gpu_check.ps1" 2>/dev/null)
if [ -n "$PACKER_SCRIPTS" ]; then
    echo "ERROR: Found duplicate base_setup scripts in Packer directories:"
    echo "$PACKER_SCRIPTS"
    echo ""
    echo "Remove these files - Packer should reference modules/vdi/scripts/base/ directly"
    exit 1
fi
```

### **CI/CD Validation**

```yaml
# .github/workflows/validate-scripts.yml
name: Validate Script Synchronization
on: [push, pull_request]

jobs:
  check-script-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check for duplicate scripts
        run: |
          if find assets/packer -name "base_setup_with_gpu_check.ps1" | grep -q .; then
            echo "ERROR: Found duplicate base_setup scripts"
            exit 1
          fi
```

## Long-term Maintenance

### **Script Modification Workflow**

1. **Edit**: Modify `modules/vdi/scripts/base/base_setup_with_gpu_check.ps1`
2. **Test**: Deploy VDI module to test runtime behavior
3. **Build**: Create new Packer AMI (uses updated script automatically)
4. **Validate**: Test both Packer AMI and VDI deployment

### **Version Management**

```hcl
# modules/vdi/scripts/base/base_setup_with_gpu_check.ps1
# Add version header for tracking
# VDI Base Setup Script
# Version: 2.1.0
# Last Modified: 2024-01-15
# Changes: Removed DCV session creation, added runtime session management
```

### **Documentation Requirements**

**Always update when modifying scripts**:
- Script version header
- VDI module README (if behavior changes)
- Packer README (if new requirements)
- CHANGELOG.md (for breaking changes)

## Migration Checklist

- [ ] Update Packer templates to reference module scripts
- [ ] Test Packer builds with new script paths
- [ ] Remove duplicate scripts from Packer directories
- [ ] Add pre-commit hook to prevent future duplicates
- [ ] Update documentation in both locations
- [ ] Add CI/CD validation for script synchronization
- [ ] Test complete workflow: script change → VDI deploy → Packer build

**Result**: Single source of truth with automated drift prevention.