# Bitcode Compilation with LTO

This document describes the bitcode compilation feature for D libraries, which enables Link-Time Optimization (LTO) using LLVM bitcode.

## Overview

Bitcode compilation allows D libraries to be compiled to LLVM bitcode intermediate representation, which can then be optimized at link time. This enables whole-program optimization and can lead to better performance.

The workflow consists of three stages:
1. **Stage 1**: Compile D sources to bitcode archive and unpack
2. **Stage 2**: Compile each bitcode object to native code with LLC (parallel)
3. **Stage 3**: Repack native objects into final archive

## Requirements

- LDC compiler (ldc2) with bitcode support
- `ar` tool (from binutils or system PATH)
- `llc` tool (from LLVM or system PATH)

The `ar` and `llc` tools can be provided by the toolchain configuration or will fall back to system versions from PATH.

## Basic Usage

### Enable Bitcode Compilation for a Library

```starlark
load("@rules_d//d:defs.bzl", "d_library")

d_library(
    name = "mylib",
    srcs = ["mylib.d"],
    compile_via_bc = "on",  # Enable bitcode compilation
)
```

### Toolchain Default

To enable bitcode compilation by default for all libraries in a toolchain:

```starlark
d_toolchain_config(
    name = "my_toolchain_config",
    d_compiler = ":ldc2",
    compile_via_bc = True,  # Enable by default
    output_bc_flags = ["-flto=full"],  # LTO flags
    # ... other config
)
```

## Configuration Options

### `compile_via_bc` Attribute

Controls whether a library is compiled via bitcode. Accepts three values:

- `"auto"` (default): Use the toolchain's default setting
- `"on"`: Enable bitcode compilation for this target
- `"off"`: Disable bitcode compilation for this target

Example:
```starlark
d_library(
    name = "optimized_lib",
    srcs = ["lib.d"],
    compile_via_bc = "on",
)

d_library(
    name = "debug_lib",
    srcs = ["debug.d"],
    compile_via_bc = "off",  # Disable even if toolchain default is on
)
```

### `qualified_object_file_names` Attribute

Controls object file naming within archives. When enabled, uses fully qualified names (e.g., `package.path.file.o` instead of `file.o`).

Accepts three values:
- `"auto"` (default): Use the toolchain's default setting
- `"on"`: Use qualified names (adds `--oq` flag to LDC)
- `"off"`: Use basename only

Example:
```starlark
d_library(
    name = "mylib",
    srcs = glob(["src/**/*.d"]),
    compile_via_bc = "on",
    qualified_object_file_names = "on",  # Use package.path.file.o naming
)
```

This is useful when you have multiple files with the same basename in different packages.

### `single_object` Attribute

Controls library compilation mode:
- `"auto"` (default): Use toolchain default
- `"on"`: Single object mode (archive with one object file)
- `"off"`: Multi-object mode (archive with multiple object files)

Bitcode compilation works with both modes.

Example:
```starlark
d_library(
    name = "single_obj_lib",
    srcs = glob(["*.d"]),
    compile_via_bc = "on",
    single_object = "on",  # Compile all sources into single object
)
```

## Toolchain Configuration

### Configuring Bitcode Support in Toolchain

```starlark
d_toolchain_config(
    name = "ldc_config",
    d_compiler = ":ldc2",

    # Bitcode compilation settings
    compile_via_bc = True,  # Enable by default
    output_bc_flags = ["-flto=full"],  # LTO flags for bitcode generation

    # Optional: provide llc compiler (otherwise uses system llc from PATH)
    llc_compiler = ":llc",

    # Optional: provide ar tool (otherwise uses system ar from PATH)
    ar_tool = ":ar",

    # Optional: qualified object names by default
    qualified_object_file_names = False,

    # Optional: codegen options for llc
    codegen_opts_common = [],
)
```

### System Tool Fallbacks

If `llc_compiler` or `ar_tool` are not specified in the toolchain configuration, the build will use the system versions from PATH:
- `llc` - LLVM static compiler
- `ar` - Archive tool from binutils

This allows bitcode compilation to work without explicit toolchain configuration for these tools.

## Examples

### Example 1: Simple Bitcode Library

```starlark
d_library(
    name = "math_lib",
    srcs = [
        "math.d",
        "geometry.d",
    ],
    compile_via_bc = "on",
)
```

### Example 2: Bitcode Library with Dependencies

```starlark
d_library(
    name = "base_lib",
    srcs = ["base.d"],
    compile_via_bc = "on",
)

d_library(
    name = "derived_lib",
    srcs = ["derived.d"],
    deps = [":base_lib"],
    compile_via_bc = "on",
)

d_binary(
    name = "app",
    srcs = ["main.d"],
    deps = [":derived_lib"],
)
```

### Example 3: Mixed Bitcode and Non-Bitcode

```starlark
d_library(
    name = "core_lib",
    srcs = ["core.d"],
    compile_via_bc = "on",  # Optimized with LTO
)

d_library(
    name = "debug_utils",
    srcs = ["debug.d"],
    compile_via_bc = "off",  # Fast compilation for debugging
)

d_binary(
    name = "app",
    srcs = ["main.d"],
    deps = [
        ":core_lib",
        ":debug_utils",
    ],
)
```

### Example 4: Library with Qualified Object Names

```starlark
d_library(
    name = "large_project",
    srcs = glob([
        "src/module1/*.d",
        "src/module2/*.d",
        "src/module3/*.d",
    ]),
    compile_via_bc = "on",
    qualified_object_file_names = "on",  # Avoid name conflicts
)
```

## How It Works

### Stage 1: Compile and Unpack

1. The D compiler (ldc2) compiles sources to a bitcode archive with `-flto=full` flag
2. The `ldc_wrapper.sh` script unpacks the bitcode archive using `ar`
3. Individual bitcode object files (`.o` containing LLVM IR) are extracted

### Stage 2: LLC Compilation (Parallel)

1. Each bitcode object file is compiled to native code independently
2. The `llc` compiler converts LLVM IR to native machine code
3. Multiple `llc` invocations run in parallel (one per object file)
4. This enables Bazel to parallelize the compilation across multiple cores

### Stage 3: Repack

1. Native object files are collected
2. The `ar` tool packs them into the final static library archive
3. The result is a native `.a` library file

## Performance Considerations

### Build Time

- **Single-object mode**: Faster for small libraries (fewer object files to process)
- **Multi-object mode**: Better parallelism for large libraries (more object files)
- **Bitcode overhead**: Additional stage 2 & 3 steps add build time
- **Caching**: Bazel caches all intermediate artifacts, so incremental builds are fast

### Runtime Performance

- **LTO benefits**: Whole-program optimization can significantly improve performance
- **Inlining**: Cross-module inlining opportunities
- **Dead code elimination**: Better elimination of unused code
- **Optimization**: llc can apply target-specific optimizations

## Troubleshooting

### Error: "llc: command not found"

The `llc` tool is not in your PATH. Either:
1. Install LLVM tools: `apt install llvm` (Ubuntu) or `brew install llvm` (macOS)
2. Configure `llc_compiler` in your toolchain to point to llc

### Error: "ar: command not found"

The `ar` tool is not in your PATH. Either:
1. Install binutils: `apt install binutils` (Ubuntu)
2. Configure `ar_tool` in your toolchain to point to ar

### Error: "No such file or directory: .bc.a"

This usually indicates a problem with the bitcode archive generation. Check:
1. LDC compiler supports `-flto=full` flag
2. `output_bc_flags` is set correctly in toolchain config
3. Library has source files to compile

### Error: "Bitcode compilation requested but toolchain.output_bc_flags not set"

Add `output_bc_flags` to your toolchain configuration:
```starlark
d_toolchain_config(
    # ...
    output_bc_flags = ["-flto=full"],
)
```

## Advanced Topics

### Custom LLC Flags

Configure custom codegen options in the toolchain:

```starlark
d_toolchain_config(
    name = "optimized_config",
    # ...
    codegen_opts_common = [
        "--relocation-model=pic",
        "--code-model=small",
    ],
)
```

### Fat LTO

For future support of fat LTO (bitcode + native code in same archive), the toolchain includes a `fat_lto` flag (currently not implemented).

## See Also

- [LDC Compiler Documentation](https://wiki.dlang.org/LDC)
- [LLVM LTO Documentation](https://llvm.org/docs/LinkTimeOptimization.html)
- [Bazel D Rules API Documentation](https://registry.bazel.build/docs/rules_d)
