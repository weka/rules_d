# Phase 4: Bitcode Compilation Notes

## Constraint: Single Object Mode Required

Bitcode compilation (via LDC's `-output-bc` flag) requires libraries to be compiled in single object mode.

### Rationale
- The fork always uses single object mode for all libraries
- Bitcode compilation produces LLVM IR that needs to be processed per compilation unit
- Archive mode (`.a` files) would create multiple bitcode files that are harder to manage

### Validation to Add in Phase 4

When implementing bitcode compilation support, add validation:

```python
# In compilation_action() for LIBRARY target_type:
if compile_via_bc and not single_object:
    fail("Bitcode compilation requires single_object mode. " +
         "Set single_object='on' or single_object='auto' with " +
         "toolchain config single_object=True.")
```

### Implementation Location

Add this validation in `upstream/d/private/rules/common.bzl` in the `compilation_action()` function, in the `TARGET_TYPE.LIBRARY` branch, after determining the `single_object` mode but before setting up compiler flags.

### Future Consideration

If there's a need to support bitcode with archive mode in the future:
- Would need to handle multiple `.bc` files per library
- Would need to update linking logic to process bitcode archives
- Consider whether this use case is actually needed in practice
