# CGD Toolkit Gold Standard Rule

## Primary Reference Document

**For ALL work on the Cloud Game Development Toolkit, use the comprehensive design standards document as your primary reference:**

📖 **[CGD Toolkit Module Design Standards](../modules/DESIGN_STANDARDS.md)**

## When to Use This Rule

**ALWAYS reference the design standards document for:**

- ✅ **Terraform module development** - New modules, updates, refactoring
- ✅ **Code reviews** - Ensuring consistency with established patterns
- ✅ **Architecture decisions** - Multi-region, networking, security patterns
- ✅ **Variable design** - Naming conventions, validation, structure
- ✅ **Provider management** - AWS Provider v6, multi-region patterns
- ✅ **Security implementations** - 0.0.0.0/0 rules, security groups, IAM
- ✅ **Documentation updates** - README structure, examples, testing
- ✅ **Breaking changes** - Migration strategies, version management
- ✅ **Logging implementations** - Centralized logging patterns
- ✅ **Remote module decisions** - When to use, fork-first strategy

## Key Principle

**The design standards document contains the collective wisdom and agreed-upon patterns for CGD Toolkit development. When in doubt, follow those standards exactly.**

## Quick Reference Sections

**Most commonly referenced sections:**

- **Core Design Philosophy** - Readability, modularity, security by default
- **Variable Design Patterns** - Naming conventions, 3-tier architecture
- **Resource Patterns** - Remote modules, logging, naming strategies
- **Security Patterns** - 0.0.0.0/0 rules, implementation patterns
- **Provider Patterns** - Multi-region, AWS Provider v6, conditional configuration
- **Implementation Checklist** - New modules, existing modules, breaking changes

## Action Required

**Before working on any CGD Toolkit code:**

1. **Read the relevant sections** of the design standards document
2. **Follow the established patterns** exactly as documented
3. **Use the checklists** to ensure completeness
4. **Reference the examples** for implementation guidance

**The design standards document is the single source of truth for CGD Toolkit development standards.**
