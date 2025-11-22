# Copyright 2015 The Bazel Authors. All rights reserved
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""D rules for Bazel."""

load("//d:toolchain.bzl", "D_TOOLCHAIN")

def _parse_bool_string(s, default):
    if s == "yes":
        return True
    elif s == "no":
        return False
    elif s == "auto":
        return default
    else:
        fail("Invalid boolean string: %s. Must be 'yes', 'no', or 'auto'." % s)

def _is_windows(ctx):
    return ctx.configuration.host_path_separator == ";"

def a_filetype(ctx, files):
    lib_suffix = ".lib" if _is_windows(ctx) else ".a"
    return [f for f in files if f.basename.endswith(lib_suffix)]

D_FILETYPE = [".d", ".di", ".h"] # TODO: restrict support of .di and .h files to source libraries

ZIP_PATH = "/usr/bin/zip"

DInfo = provider()

def _with_runfiles(tool):
    """Returns a list of files _and_ runfiles for `tool`."""
    files = tool.files.to_list()
    runfiles = tool[DefaultInfo].default_runfiles
    if runfiles:
        files += runfiles.files.to_list()
    return files

def _files_directory(files):
    """Returns the shortest parent directory of a list of files."""
    dir = files[0].dirname
    for f in files:
        if len(dir) > len(f.dirname):
            dir = f.dirname
    return dir

DEFAULT_COMPILATION_MODE_FLAGS_POSIX = {
    "fastbuild": ["-g"],
    "dbg": ["-d-debug", "-d-version=debug_assert", "-g"],
    "opt": ["-checkaction=halt", "-boundscheck=safeonly", "-O"],
}

DEFAULT_COMPILATION_MODE_FLAGS_WINDOWS = {
    "fastbuild": ["-g", "-m64", "-mscrtlib=msvcrt"],
    "dbg": ["-debug", "-g", "-m64", "-mscrtlib=msvcrtd"],
    "opt": [
        "-checkaction=halt",
        "-boundscheck=safeonly",
        "-O",
        "-m64",
        "-mscrtlib=msvcrt",
    ],
}

def _default_compilation_mode_flags(ctx):
    """Returns the default compilation mode flags."""
    if _is_windows(ctx):
        return DEFAULT_COMPILATION_MODE_FLAGS_WINDOWS[ctx.var["COMPILATION_MODE"]]
    else:
        return DEFAULT_COMPILATION_MODE_FLAGS_POSIX[ctx.var["COMPILATION_MODE"]]

def _compilation_mode_flags_helper(ctx):
    """Helper function to return the flags for the compilation mode."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    compilation_mode = ctx.var["COMPILATION_MODE"]
    default_flags = _default_compilation_mode_flags(ctx)
    if compilation_mode == "dbg":
        return toolchain.dbg_flags or default_flags
    elif compilation_mode == "opt":
        return toolchain.opt_flags or default_flags
    elif compilation_mode == "fastbuild":
        return toolchain.fastbuild_flags or default_flags
    else:
        fail("Invalid compilation mode: %s" % compilation_mode)

def _compilation_mode_flags(ctx):
    """Returns a list of flags based on the compilation mode."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    return (toolchain.common_flags or []) + _compilation_mode_flags_helper(ctx)

def _format_version(name):
    """Formats the string name to be used in a --version flag."""
    return name.replace("-", "_")

def _build_import(label, im, gen_dir = None):
    """Builds the import path under a specific label"""
    import_path = ""
    if label.workspace_root:
        import_path += label.workspace_root + "/"
    if label.package:
        import_path += label.package + "/"
    if im == ".":
        import_path = import_path[0:len(import_path) - 1]
    else:
        import_path += im
    if gen_dir:
        import_path = gen_dir + "/" + import_path
    return import_path

def _build_compile_arglist(ctx, out, depinfo, extra_flags = []):
    """Returns a list of strings constituting the D compile command arguments."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    version_flag = toolchain.version_flag
    gen_dir = ctx.genfiles_dir.path if ctx.attr.is_generated else None

    ws_root = gen_dir if ctx.attr.is_generated else "."

    versions = depset(
        toolchain.global_versions_common + toolchain.global_versions_per_mode[ctx.var["COMPILATION_MODE"]],
        transitive = [depinfo.versions])

    compile_via_bc = _parse_bool_string(ctx.attr.compile_via_bc, toolchain.compile_via_bc)

    return (
        _compilation_mode_flags(ctx) +
        extra_flags + [
            "-of" + out.path,
            "-w",
        ] +
        (toolchain.output_bc_flags if compile_via_bc else []) +
        (["-I%s" % ws_root] if ctx.attr.include_workspace_root else []) +
        ["-I%s" % im for im in depinfo.imports] +
        ["-J%s" % im for im in depinfo.string_imports] +
        # toolchain.import_flags +
        [version_flag + "=%s" % v for v in versions.to_list()]
    )

def _sort_objects(objs, link_order):
    """Sorts the objects in the order they need to be linked."""
    if not link_order:
        return [o.path for o in objs]
    return [
        obj.path for i, obj in sorted(enumerate(objs), key=lambda x: link_order.get(x[1].path, x[0]))
    ]

def _link_order_dict(objs, link_order):
    """Builds a dictionary mapping object file paths to their link order index."""
    if not link_order:
        return {}
    size = len(objs)
    link_order_dict = dict()
    for k, v in link_order.items():
        idx = int(v)
        if idx < 0:
            idx = size - 1 - idx
        for p in k.files.to_list():
            link_order_dict[p.path] = idx
    return link_order_dict

def _build_link_arglist(ctx, objs, out, depinfo, c_compiler, link_flags, link_order, fat_lto):
    """Returns a list of strings constituting the D link command arguments."""
    if not fat_lto:
        transitive_libs = [depinfo.libs, depinfo.transitive_libs]
    else:
        transitive_libs = [depinfo.libs_bc, depinfo.libs_non_bc, depinfo.transitive_libs_bc, depinfo.transitive_libs_non_bc]
    all_objs = objs + depset(transitive = transitive_libs).to_list()
    sorted_objs = _sort_objects(all_objs, _link_order_dict(all_objs, link_order))
    return (
        _compilation_mode_flags(ctx) +
        (["-gcc=%s" % c_compiler.files.to_list()[0].path] if c_compiler else []) +
        (link_flags or []) +
        (["-L--dynamic-list=%s" % ctx.files.dynamic_symbols[0].path] if ctx.files.dynamic_symbols else []) +
        ["-of" + out.path] +
        depinfo.link_flags +
        sorted_objs
    )

def _find_gensrc_location(loc, src):
    if loc.startswith("@"):
        fail("Cannot place the generated source %s into location %s" % (
                src, loc))
    if loc.startswith("//"):
        label = Label(loc)
        return label.package + "/" + label.name
    return src.label.package + "/" + loc

def _setup_deps(ctx, deps, impl_deps, name):
    """Sets up dependencies.

    Walks through dependencies and constructs the commands and flags needed
    for linking the necessary dependencies.

    Args:
      ctx: The context of the current target.
      deps: List of deps labels from ctx.attr.deps.
      impl_deps: List of deps labels from ctx.attr.implementation_deps.
      name: Name of the current target.

    Returns:
      Returns a struct containing the following fields:
        libs: List of Files containing the target's direct library dependencies.
        transitive_libs: List of Files containing all of the target's
            transitive libraries.
        transitive_bc_libs: List of transitive deps as bc files (where they exist)
        transitive_non_bc_libs: List of transitive deps that don't exists as bc
        d_srcs: List of Files representing D source files of dependencies that
            will be used as inputs for this target.
        versions: List of D versions to be used for compiling the target.
        imports: List of Strings containing input paths that will be passed
            to the D compiler via -I flags.
        string_imports: List of strings containing input paths that will be
            passed to the D compiler via -J flags.
        link_flags: List of linker flags.
        generated_srcs: A dictionary mapping generated files to their
            desired locations.
        data: List of Files containing extra (non-source) files that will
            be used as inputs for this target.
    """

    gen_dir = ctx.genfiles_dir.path
    libs = []
    libs_bc = []
    libs_non_bc = []
    transitive_libs = []
    transitive_libs_bc = []
    transitive_libs_non_bc = []
    d_srcs = []
    data = []
    transitive_d_srcs = []
    transitive_data = []
    versions = ctx.attr.versions + ["Have_%s" % _format_version(name)]
    transitive_versions = []
    gen_dir_for_imports = gen_dir if ctx.attr.is_generated else None
    imports = [_build_import(ctx.label, im, gen_dir_for_imports) for im in ctx.attr.imports]
    string_imports = [_build_import(ctx.label, im, gen_dir_for_imports) for im in ctx.attr.string_imports]
    link_flags = []
    generated_srcs = {
        src.files.to_list()[0]: _find_gensrc_location(loc, src) for src, loc in ctx.attr.generated_srcs.items()}
    for dep in deps:
        if DInfo in dep and hasattr(dep[DInfo], "d_lib"):
            # The dependency is a d_library.
            ddep = dep[DInfo]
            if ddep.d_lib:
                libs.append(ddep.d_lib)
                if ddep.d_lib_bc:
                    libs_bc.append(ddep.d_lib_bc)
                else:
                    libs_non_bc.append(ddep.d_lib)
            transitive_libs.append(ddep.transitive_libs)
            transitive_libs_bc.append(ddep.transitive_libs_bc)
            transitive_libs_non_bc.append(ddep.transitive_libs_non_bc)

            d_srcs += ddep.d_exports
            transitive_d_srcs.append(ddep.transitive_d_srcs)
            data += ddep.data
            transitive_data.append(ddep.transitive_data)
            transitive_versions.append(ddep.versions)
            link_flags.extend(ddep.link_flags)
            link_flags += ["-L%s" % linkopt for linkopt in ddep.linkopts]
            imports += ddep.imports
            if ddep.is_generated:
                imports.append(gen_dir)
            string_imports += ddep.string_imports
            generated_srcs = generated_srcs | ddep.generated_srcs

        elif DInfo in dep and hasattr(dep[DInfo], "d_srcs"):
            # The dependency is a d_source_library.
            ddep = dep[DInfo]
            d_srcs += ddep.d_srcs
            transitive_d_srcs.append(ddep.transitive_d_srcs)
            data += ddep.data
            transitive_data.append(ddep.transitive_data)
            transitive_libs.append(ddep.transitive_libs)
            transitive_libs_bc.append(ddep.transitive_libs_bc)
            transitive_libs_non_bc.append(ddep.transitive_libs_non_bc)
            link_flags += ["-L%s" % linkopt for linkopt in ddep.linkopts]
            imports += ddep.imports
            if ddep.is_generated:
                imports.append(gen_dir)
            string_imports += ddep.string_imports
            transitive_versions.append(ddep.versions)
            generated_srcs = generated_srcs | ddep.generated_srcs

        elif CcInfo in dep:
            # The dependency is a cc_library
            native_libs = a_filetype(ctx, _get_libs_for_static_executable(dep))
            libs.extend(native_libs)
            libs_non_bc.extend(native_libs)
            transitive_libs.append(depset(native_libs))
            transitive_libs_non_bc.append(depset(native_libs))

        else:
            fail("D targets can only depend on d_library, d_source_library, or " +
                 "cc_library targets.", dep)

    impl_srcs = []
    for dep in impl_deps:
        if DInfo in dep and hasattr(dep[DInfo], "d_lib"):
            ddep = dep[DInfo]
            libs.append(ddep.d_lib)
            if ddep.d_lib_bc:
                libs_bc.append(ddep.d_lib_bc)
            else:
                libs_non_bc.append(ddep.d_lib)
            transitive_libs.append(ddep.transitive_libs)
            transitive_libs_bc.append(ddep.transitive_libs_bc)
            transitive_libs_non_bc.append(ddep.transitive_libs_non_bc)
            impl_srcs.extend(ddep.d_exports)
        elif CcInfo in dep:
            native_libs = a_filetype(ctx, _get_libs_for_static_executable(dep))
            libs.extend(native_libs)
            libs_non_bc.extend(native_libs)
            transitive_libs.append(depset(native_libs))
            transitive_libs_non_bc.append(depset(native_libs))
        else:
            fail("Implementation dependencies can only depend on d_library or cc_library targets.", dep)

    return struct(
        libs = depset(libs),
        libs_bc = depset(libs_bc),
        libs_non_bc = depset(libs_non_bc),
        transitive_libs = depset(transitive = transitive_libs),
        transitive_libs_bc = depset(transitive = transitive_libs_bc),
        transitive_libs_non_bc = depset(transitive = transitive_libs_non_bc),
        transitive_d_srcs = depset(d_srcs, transitive = transitive_d_srcs),
        data = depset(data).to_list(),
        transitive_data = depset(transitive = transitive_data),
        versions = depset(versions, transitive = transitive_versions),
        imports = depset(imports).to_list(),
        string_imports = depset(string_imports).to_list(),
        link_flags = depset(link_flags).to_list(),
        generated_srcs = generated_srcs,
        impl_srcs = impl_srcs,
    )

def _handle_generated_srcs(ctx, generated_srcs, d_compiler, debug_repo_root_override):
    """Handles the generated source files."""
    if not generated_srcs and not debug_repo_root_override:
        return (ctx.files.srcs, None)
    mapped_srcs = [src if src not in generated_srcs else generated_srcs[src] for src in ctx.files.srcs]

    wrapper = ctx.actions.declare_file(ctx.label.name + "_d_compile_wrapper.sh")
    debug_prefix_map = "-fdebug-prefix-map=$PWD=%s " % debug_repo_root_override if debug_repo_root_override else ""
    ctx.actions.write(
        output = wrapper,
        content = "\n".join(
            [
                "#!/bin/bash",
                "set -e",
            ] +
            [
                "mkdir -p $(dirname %s)\n" % loc +
                "[ -f $PWD/%s ] && ln -s $PWD/%s %s" % (src.path, src.path, loc) for src, loc in generated_srcs.items()
            ] + [
                "%s %s$*" % (d_compiler.path, debug_prefix_map),
            ]),
        is_executable = True,
    )

    return (mapped_srcs, wrapper)

def _d_library_impl_common(ctx, extra_flags = []):
    """Implementation of the d_library rule."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    d_compiler = toolchain.d_compiler.files.to_list()[0]

    compile_via_bc = _parse_bool_string(ctx.attr.compile_via_bc, toolchain.compile_via_bc)
    if compile_via_bc and not toolchain.output_bc_flags:
        fail("'compile_via_bc' requires a toolchain with 'output_bc_flags' set")

    # Dependencies
    deps = ctx.attr.deps + ([toolchain.libphobos] if toolchain.libphobos != None else []) + ([toolchain.druntime] if toolchain.druntime != None else [])
    depinfo = _setup_deps(ctx, ctx.attr.deps, ctx.attr.implementation_deps, ctx.label.name)

    public_srcs = ctx.files.hdrs + ctx.files.exports
    if not public_srcs:
        public_srcs = ctx.files.srcs

    if not ctx.files.srcs:
        return [
            DefaultInfo(
                files = depset(),
            ),
            DInfo(
                d_srcs = ctx.files.srcs,
                d_exports = public_srcs,
                transitive_d_srcs = depinfo.transitive_d_srcs,
                data = ctx.files.data,
                transitive_data = depset(depinfo.data, transitive = [depinfo.transitive_data]),
                transitive_libs = depset(transitive = [depinfo.libs, depinfo.transitive_libs]),
                transitive_libs_bc = depset(transitive = [depinfo.libs_bc, depinfo.transitive_libs_bc]),
                transitive_libs_non_bc = depset(transitive = [depinfo.libs_non_bc, depinfo.transitive_libs_non_bc]),
                link_flags = depinfo.link_flags,
                linkopts = ctx.attr.linkopts,
                versions = depinfo.versions,
                imports = depinfo.imports,
                string_imports = depinfo.string_imports,
                d_lib = "",  # TODO: we only need it to distinguish from d_source_library. Either drop d_source_library or make another provider for it.
                is_generated = ctx.attr.is_generated,
                generated_srcs = depinfo.generated_srcs,
            ),
        ]

    #d_lib = ctx.actions.declare_file((ctx.label.name + ".lib") if _is_windows(ctx) else ("lib" + ctx.label.name + ".a"))
    d_lib = ctx.actions.declare_file(ctx.label.name + ".o")
    d_lib_bc = None
    if compile_via_bc:
        d_lib_bc = ctx.actions.declare_file(ctx.label.name + ".bc.o")

    # Build compile command.
    compile_args = _build_compile_arglist(
        ctx = ctx,
        out = d_lib if not d_lib_bc else d_lib_bc,
        depinfo = depinfo,
        extra_flags = ["-c"] + extra_flags,
    )

    # Convert sources to args
    # This is done to support receiving a File that is a directory, as
    # args will auto-expand this to the contained files
    args = ctx.actions.args()
    args.add_all(compile_args)

    mapped_srcs, generated_srcs_wrapper = _handle_generated_srcs(ctx, depinfo.generated_srcs, d_compiler, toolchain.debug_repo_root_override)

    args.add_all(mapped_srcs)

    phobos_files = toolchain.libphobos.files if toolchain.libphobos != None else depset()
    phobos_src_files = toolchain.libphobos_src.files if toolchain.libphobos_src != None else depset()
    druntime_src_files = toolchain.druntime_src.files if toolchain.druntime_src != None else depset()
    # TODO: Should they be in transitive?
    compile_inputs = depset(
        ctx.files.srcs +
        ctx.files.hdrs +
        ctx.files.exports +
        ctx.files.data +
        depinfo.data +
        depinfo.impl_srcs,
        transitive = [
            depinfo.transitive_d_srcs,
            depinfo.transitive_data,
            phobos_files,
            phobos_src_files,
            druntime_src_files,
        ],
    )

    executable = generated_srcs_wrapper if generated_srcs_wrapper else d_compiler
    ctx.actions.run(
        inputs = compile_inputs,
        tools = _with_runfiles(toolchain.d_compiler) + ([generated_srcs_wrapper] if generated_srcs_wrapper else []),
        outputs = [d_lib] if not d_lib_bc else [d_lib_bc],
        mnemonic = "Dcompile",
        executable = executable,
        arguments = [args],
        use_default_shell_env = True,
        progress_message = "Compiling D library " + ctx.label.name,
    )

    if d_lib_bc:
        # need to compile .bc.o -> .o in an extra step
        codegen_flags = toolchain.codegen_common_flags + toolchain.codegen_per_mode_flags[ctx.var["COMPILATION_MODE"]]
        # this is a hack, just hoping there is some llc is not good
        # TODO: enforce this is only used with toolchain.llc_compiler
        # This also _could_ be clang, but aligning LDC backend options with
        # clang ones is non-trivial, whereas llc has exactly the same options
        # as ldc does.
        llc = toolchain.llc_compiler.files.to_list()[0] if toolchain.llc_compiler else "llc"
        ctx.actions.run(
            inputs = [d_lib_bc],
            tools = _with_runfiles(toolchain.llc_compiler) if toolchain.llc_compiler else [],
            outputs = [d_lib],
            executable = llc,
            arguments = codegen_flags + ["--filetype=obj", "-o", d_lib.path, d_lib_bc.path],
            use_default_shell_env = True,
            progress_message = "Compiling bitcode for D library " + ctx.label.name,
        )
    return [
        DefaultInfo(
            files = depset([d_lib]),
        ),
        DInfo(
            d_srcs = ctx.files.srcs,
            d_exports = public_srcs,
            transitive_d_srcs = depinfo.transitive_d_srcs,
            data = ctx.files.data,
            transitive_data = depset(depinfo.data, transitive = [depinfo.transitive_data]),
            transitive_libs = depset(transitive = [depinfo.libs, depinfo.transitive_libs]),
            transitive_libs_bc = depset(transitive = [depinfo.libs_bc, depinfo.transitive_libs_bc]),
            transitive_libs_non_bc = depset(transitive = [depinfo.libs_non_bc, depinfo.transitive_libs_non_bc]),
            link_flags = depinfo.link_flags,
            linkopts = ctx.attr.linkopts,
            versions = depinfo.versions,
            imports = depinfo.imports,
            string_imports = depinfo.string_imports,
            d_lib = d_lib,
            d_lib_bc = d_lib_bc,
            is_generated = ctx.attr.is_generated,
            generated_srcs = depinfo.generated_srcs,
        ),
    ]

def _d_binary_impl_common(ctx, extra_flags = []):
    """Common implementation for rules that build a D binary."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    d_bin = ctx.actions.declare_file(ctx.label.name + ".exe" if _is_windows(ctx) else ctx.label.name)
    d_compiler = toolchain.d_compiler.files.to_list()[0]

    # Dependencies
    deps = ctx.attr.deps + ([toolchain.libphobos] if toolchain.libphobos != None else []) + ([toolchain.druntime] if toolchain.druntime != None else [])
    depinfo = _setup_deps(ctx, deps, [], ctx.label.name)

    d_obj = None
    toolchain_files = [
        toolchain.libphobos.files if toolchain.libphobos != None else depset(),
        toolchain.libphobos_src.files if toolchain.libphobos_src != None else depset(),
        toolchain.druntime_src.files if toolchain.druntime_src != None else depset(),
    ]

    d_obj_bc = None
    compile_via_bc = _parse_bool_string(ctx.attr.compile_via_bc, toolchain.compile_via_bc)
    fat_lto = _parse_bool_string(ctx.attr.fat_lto, toolchain.fat_lto)
    if ctx.files.srcs:
        if compile_via_bc or fat_lto:
            if not toolchain.output_bc_flags:
                fail("'compile_via_bc' and 'fat_lto' require a toolchain with 'output_bc_flags' set")
            d_obj_bc = ctx.actions.declare_file(ctx.label.name + ".bc.o")

        d_obj = ctx.actions.declare_file(ctx.label.name + (".obj" if _is_windows(ctx) else ".o"))
        # Build compile command
        compile_args = _build_compile_arglist(
            ctx = ctx,
            depinfo = depinfo,
            out = d_obj if not d_obj_bc else d_obj_bc,
            extra_flags = ["-c"] + extra_flags,
        )

        # Convert sources to args
        # This is done to support receiving a File that is a directory, as
        # args will auto-expand this to the contained files
        args = ctx.actions.args()
        args.add_all(compile_args)

        mapped_srcs, generated_srcs_wrapper = _handle_generated_srcs(ctx, depinfo.generated_srcs, d_compiler, toolchain.debug_repo_root_override)

        args.add_all(mapped_srcs)

        compile_inputs = depset(
            ctx.files.srcs + ctx.files.data + depinfo.data,
            transitive = [depinfo.transitive_d_srcs, depinfo.transitive_data] + toolchain_files,
        )
        ctx.actions.run(
            inputs = compile_inputs,
            tools = _with_runfiles(toolchain.d_compiler) + ([generated_srcs_wrapper] if generated_srcs_wrapper else []),
            outputs = [d_obj] if not d_obj_bc else [d_obj_bc],
            mnemonic = "Dcompile",
            executable = generated_srcs_wrapper if generated_srcs_wrapper else d_compiler,
            arguments = [args],
            use_default_shell_env = True,
            progress_message = "Compiling D binary " + ctx.label.name,
        )

        if d_obj_bc:
            # TODO: this code is almost exactly the same as in d_library
            # need to compile .bc.o -> .o in an extra step
            codegen_flags = toolchain.codegen_common_flags + toolchain.codegen_per_mode_flags[ctx.var["COMPILATION_MODE"]]
            # this is a hack, just hoping there is some llc is not good
            # TODO: enforce this is only used with toolchain.llc_compiler
            # This also _could_ be clang, but aligning LDC backend options with
            # clang ones is non-trivial, whereas llc has exactly the same options
            # as ldc does.
            llc = toolchain.llc_compiler.files.to_list()[0] if toolchain.llc_compiler else "llc"
            ctx.actions.run(
                inputs = [d_obj_bc],
                tools = _with_runfiles(toolchain.llc_compiler) if toolchain.llc_compiler else [],
                outputs = [d_obj],
                executable = llc,
                arguments = codegen_flags + ["--filetype=obj", "-o", d_obj.path, d_obj_bc.path],
                use_default_shell_env = True,
                progress_message = "Compiling bitcode for D binary " + ctx.label.name,
            )

    obj = d_obj_bc if fat_lto else d_obj
    # Build link command
    link_args = _build_link_arglist(
        ctx = ctx,
        objs = [obj] if obj else [],
        depinfo = depinfo,
        out = d_bin,
        c_compiler = toolchain.c_compiler,
        link_flags = toolchain.link_flags + ["-L%s" % linkopt for linkopt in ctx.attr.linkopts],
        link_order = ctx.attr.link_order,
        fat_lto = fat_lto,
    )

    if fat_lto:
        libs = [depinfo.libs_bc, depinfo.libs_non_bc, depinfo.transitive_libs_bc, depinfo.transitive_libs_non_bc]
    else:
        libs = [depinfo.libs, depinfo.transitive_libs]
    link_inputs = depset(
        ([obj] if obj else []) + ([ctx.files.dynamic_symbols[0]] if ctx.files.dynamic_symbols else []),
        transitive = libs + toolchain_files,
    )

    ctx.actions.run(
        inputs = link_inputs,
        tools = _with_runfiles(toolchain.d_compiler) + (_with_runfiles(toolchain.c_compiler) if toolchain.c_compiler else []),
        outputs = [d_bin],
        mnemonic = "Dlink",
        executable = d_compiler,
        arguments = link_args,
        use_default_shell_env = True,
        progress_message = "Linking " + ("(with fat LTO) " if fat_lto else "") + "D binary " + ctx.label.name,
    )

    return [
        DInfo(
            d_srcs = ctx.files.srcs,
            transitive_d_srcs = depinfo.transitive_d_srcs,
            data = ctx.files.data,
            transitive_data = depset(depinfo.data),
            imports = ctx.attr.imports,
            string_imports = ctx.attr.string_imports,
        ),
        DefaultInfo(
            executable = d_bin,
        ),
    ]

def _d_library_impl(ctx):
    """Implementation of the d_library rule."""
    return _d_library_impl_common(ctx)

def _d_test_library_impl(ctx):
    """Implementation of the d_test_library rule."""
    # A test library is just a d_library with testonly=True
    return _d_library_impl_common(ctx, extra_flags=["-unittest"])

def _d_binary_impl(ctx):
    """Implementation of the d_binary rule."""
    return _d_binary_impl_common(ctx)

def _d_test_impl(ctx):
    """Implementation of the d_test rule."""
    return _d_binary_impl_common(ctx, extra_flags = ["-unittest"])

def _get_libs_for_static_executable(dep):
    """
    Finds the libraries used for linking an executable statically.
    This replaces the old API dep.cc.libs
    Args:
      dep: Target
    Returns:
      A list of File instances, these are the libraries used for linking.
    """
    libs = []
    for li in dep[CcInfo].linking_context.linker_inputs.to_list():
        for library_to_link in li.libraries:
            if library_to_link.static_library != None:
                libs.append(library_to_link.static_library)
            elif library_to_link.pic_static_library != None:
                libs.append(library_to_link.pic_static_library)
            elif library_to_link.interface_library != None:
                libs.append(library_to_link.interface_library)
            elif library_to_link.dynamic_library != None:
                libs.append(library_to_link.dynamic_library)
    return libs

def _d_source_library_impl(ctx):
    """Implementation of the d_source_library rule."""
    transitive_d_srcs = []
    transitive_data = []
    transitive_libs = []
    transitive_transitive_libs = []
    transitive_transitive_libs_bc = []
    transitive_transitive_libs_non_bc = []
    transitive_imports = depset()
    transitive_string_imports = depset()
    transitive_linkopts = depset()
    transitive_versions = depset()
    generated_srcs = {
        src.files.to_list()[0]: src.label.package + "/" + loc for src, loc in ctx.attr.generated_srcs.items()}
    for dep in ctx.attr.deps:
        if DInfo in dep and hasattr(dep[DInfo], "d_srcs") and not hasattr(dep[DInfo], "d_lib"):
            # Dependency is another d_source_library target.
            # TODO: Could we also support d_library here?
            ddep = dep[DInfo]
            transitive_d_srcs.append(depset(ddep.d_srcs, transitive = [ddep.transitive_d_srcs]))
            transitive_data.append(depset(ddep.data))
            transitive_imports = depset(ddep.imports, transitive = [transitive_imports])
            transitive_string_imports = depset(ddep.string_imports, transitive = [transitive_string_imports])
            transitive_linkopts = depset(ddep.linkopts, transitive = [transitive_linkopts])
            transitive_versions = depset(transitive = [ddep.versions, transitive_versions])
            transitive_transitive_libs.append(ddep.transitive_libs)
            transitive_transitive_libs_bc.append(ddep.transitive_libs_bc)
            transitive_transitive_libs_non_bc.append(ddep.transitive_libs_non_bc)
            generated_srcs = generated_srcs | ddep.generated_srcs

        elif CcInfo in dep:
            # Dependency is a cc_library target.
            native_libs = a_filetype(ctx, _get_libs_for_static_executable(dep))
            transitive_libs.extend(native_libs)

        else:
            fail("d_source_library can only depend on other " +
                 "d_source_library or cc_library targets.", "deps")

    gen_dir = ctx.genfiles_dir.path if ctx.attr.is_generated else None

    return [
        DInfo(
            d_srcs = ctx.files.srcs,
            data = ctx.files.data,
            transitive_d_srcs = depset(transitive = transitive_d_srcs, order = "postorder"),
            transitive_data = depset(transitive = transitive_data, order = "postorder"),
            transitive_libs = depset(transitive_libs, transitive = transitive_transitive_libs),
            transitive_libs_bc = depset(transitive_libs, transitive = transitive_transitive_libs_bc),
            transitive_libs_non_bc = depset(transitive_libs, transitive = transitive_transitive_libs_non_bc),
            imports = [_build_import(ctx.label, im, gen_dir) for im in ctx.attr.imports] + transitive_imports.to_list(),
            string_imports = [_build_import(ctx.label, im, gen_dir) for im in ctx.attr.string_imports] + transitive_string_imports.to_list(),
            linkopts = ctx.attr.linkopts + transitive_linkopts.to_list(),
            versions = depset(ctx.attr.versions, transitive = [transitive_versions]),
            is_generated = ctx.attr.is_generated,
            generated_srcs = generated_srcs,
        ),
    ]

# TODO(dzc): Use ddox for generating HTML documentation.
def _d_docs_impl(ctx):
    """Implementation for the d_docs rule

      This rule runs the following steps to generate an archive containing
      HTML documentation generated from doc comments in D source code:
        1. Run the D compiler with the -D flags to generate HTML code
           documentation.
        2. Create a ZIP archive containing the HTML documentation.
    """
    d_docs_zip = ctx.outputs.d_docs
    docs_dir = d_docs_zip.dirname + "/_d_docs"
    objs_dir = d_docs_zip.dirname + "/_d_objs"

    target = struct(
        name = ctx.attr.dep.label.name,
        srcs = ctx.attr.dep[DInfo].d_srcs,
        transitive_srcs = ctx.attr.dep[DInfo].transitive_d_srcs,
        imports = ctx.attr.dep[DInfo].imports,
    )

    toolchain = ctx.toolchains[D_TOOLCHAIN]
    d_compiler = toolchain.d_compiler.files.to_list()[0]

    # Build D docs command
    doc_cmd = (
        [
            "set -e;",
            "rm -rf %s; mkdir -p %s;" % (docs_dir, docs_dir),
            "rm -rf %s; mkdir -p %s;" % (objs_dir, objs_dir),
            d_compiler.path,
            "-c",
            "-D",
            "-Dd%s" % docs_dir,
            "-od%s" % objs_dir,
            "-I.",
        ] +
        ["-I%s" % _build_import(ctx.label, im) for im in target.imports] +
        # toolchain.import_flags +
        [src.path for src in target.srcs] +
        [
            "&&",
            "(cd %s &&" % docs_dir,
            ZIP_PATH,
            "-qR",
            d_docs_zip.basename,
            "$(find . -type f) ) &&",
            "mv %s/%s %s" % (docs_dir, d_docs_zip.basename, d_docs_zip.path),
        ]
    )

    toolchain_files = [
        toolchain.libphobos.files if toolchain.libphobos != None else depset(),
        toolchain.libphobos_src.files if toolchain.libphobos_src != None else depset(),
        toolchain.druntime_src.files if toolchain.druntime_src != None else depset(),
    ]

    ddoc_inputs = depset(target.srcs, transitive = [target.transitive_srcs] + toolchain_files)
    ctx.actions.run_shell(
        inputs = ddoc_inputs,
        tools = _with_runfiles(toolchain.d_compiler),
        outputs = [d_docs_zip],
        mnemonic = "Ddoc",
        command = " ".join(doc_cmd),
        use_default_shell_env = True,
        progress_message = "Generating D docs for " + ctx.label.name,
    )

def _d_header_generator_impl(ctx):
    """Implementation of the d_header_generator rule."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    if not toolchain.hdrgen_flags:
        fail("d_header_generator requires a toolchain with hdrgen_flags set.")

    d_compiler = toolchain.d_compiler.files.to_list()[0]

    infile = ctx.file.src
    if not infile:
        fail("d_header_generator requires a single source file.")

    if not infile.path.endswith(".d"):
        fail("d_header_generator only supports .d files, got: %s" % infile.path)

    header = ctx.actions.declare_file(ctx.label.name + ".di")

    ctx.actions.run(
        inputs = [ctx.file.src],
        tools = _with_runfiles(toolchain.d_compiler),
        outputs = [header],
        mnemonic = "Dhdrgen",
        executable = d_compiler,
        arguments = toolchain.hdrgen_flags + [infile.path, "--Hf", header.path],
        use_default_shell_env = True,
        progress_message = "Generating D header for " + ctx.label.name,
    )
    return [
        DefaultInfo(
            files = depset([header]),
        ),
        DInfo(
            d_exports = [header]
        ),
    ]

_d_common_attrs = {
    "srcs": attr.label_list(allow_files = D_FILETYPE),
    "imports": attr.string_list(),
    "string_imports": attr.string_list(),
    "data": attr.label_list(allow_files = True),
    "linkopts": attr.string_list(),
    "versions": attr.string_list(),
    "include_workspace_root": attr.bool(default = True),
    "is_generated": attr.bool(default = False),
    "generated_srcs": attr.label_keyed_string_dict(allow_files = True),
    "compile_via_bc": attr.string(doc = """
    Whether to compile with an intermediate bitcode file. If "yes" or "no", this overrides the default setting in the toolchain.
    If "auto", the default setting in the toolchain is used.
    This is only supported for LDC.
    """, default = "auto"),
    "deps": attr.label_list(),
}

_d_library_attrs = {
    "hdrs": attr.label_list(allow_files = D_FILETYPE, allow_empty = True),
    "exports": attr.label_list(allow_files = D_FILETYPE),
    "implementation_deps": attr.label_list(),
}

_d_binary_attrs = {
    "dynamic_symbols" : attr.label(allow_files = True),
    "link_order": attr.label_keyed_string_dict(),
    "fat_lto": attr.string(doc = """
    Whether to force fat LTO. If "yes" or "no", this overrides the default setting in the toolchain.
    If "auto", the default setting in the toolchain is used.
    This is only supported for LDC.
    """, default = "auto"),
}

# _d_compile_attrs = {
#     "_d_compiler": attr.label(
#         default = Label("//d:dmd"),
#         executable = True,
#         allow_single_file = True,
#         cfg = "host",
#     ),
#     "_d_runtime_import_src": attr.label(
#         default = Label("//d:druntime-import-src"),
#     ),
#     "_d_stdlib": attr.label(
#         default = Label("//d:libphobos2"),
#     ),
#     "_d_stdlib_src": attr.label(
#         default = Label("//d:phobos-src"),
#     ),
# }

d_library = rule(
    _d_library_impl,
    attrs = dict(_d_common_attrs.items() + _d_library_attrs.items()),
    toolchains = [D_TOOLCHAIN],
)

d_test_library = rule(
    _d_test_library_impl,
    attrs = dict(_d_common_attrs.items() + _d_library_attrs.items()),
    toolchains = [D_TOOLCHAIN],
)

d_header_generator = rule(
    _d_header_generator_impl,
    attrs = {
        "src": attr.label(
            mandatory = True,
            allow_single_file = [".d"],
        ),
    },
    toolchains = [D_TOOLCHAIN],
)

d_source_library = rule(
    _d_source_library_impl,
    attrs = _d_common_attrs,
    toolchains = [D_TOOLCHAIN],
)

d_binary = rule(
    _d_binary_impl,
    attrs = dict(_d_common_attrs.items() + _d_binary_attrs.items()),
    executable = True,
    toolchains = [D_TOOLCHAIN],
)

d_test = rule(
    _d_test_impl,
    attrs = dict(_d_common_attrs.items() + _d_binary_attrs.items()),
    executable = True,
    test = True,
    toolchains = [D_TOOLCHAIN],
)

_d_docs_attrs = {
    "dep": attr.label(mandatory = True),
}

d_docs = rule(
    _d_docs_impl,
    attrs = dict(_d_docs_attrs.items()),
    outputs = {
        "d_docs": "%{name}-docs.zip",
    },
    toolchains = [D_TOOLCHAIN],
)

def d_lib(
    name,
    srcs = [],
    imports = [],
    string_imports = [],
    data = [],
    linkopts = [],
    versions = [],
    hdrs = [],
    exports = [],
    exports_no_hdrs = [],
    deps = [],
    implementation_deps = [],
    include_workspace_root = True,
    is_generated = False,
    generated_srcs = {},
    test = False,
    exports_lib = None,
    **kwargs,
):
    """d_lib is a macro that can generate header files for a D library.

    It wraps the d_library rule and automatically generates header files
    for the exported D source files. It takes mostly the same arguments
    as d_library, plus an additional `exports_no_hdrs` argument that
    specifies the exported D source files that should be exported without
    generating headers for them (this might be useful if they contain
    non-templated functions that need to be called during CTFE).
    Args:
      name: The name of the target.
      srcs: List of D source files to compile.
      imports: List of import paths to include in the compilation.
      string_imports: List of string import paths to include in the compilation.
      data: List of extra files to include in the compilation.
      linkopts: List of linker options to pass to the linker.
      versions: List of D versions to define during compilation.
      hdrs: List of header files to include in the library.
      exports: List of D source files to export, which will have headers generated for them.
      exports_no_hdrs: List of D source files to export without generating headers.
      deps: List of dependencies for this library.
      implementation_deps: List of implementation dependencies for this library.
      include_workspace_root: Whether to include the workspace root in import paths.
      is_generated: Whether this library is generated (used for generated sources).
      generated_srcs: A dictionary mapping generated source files to their desired locations.
      test: Whether this library is a test library (compiled with -unittest flag).
      exports_lib: Optional label of a d_library target that contains the exported files.
          If provided, will create an extra `d_source_library` with headers+exports.
          This could be used to break a circular dependency.
      **kwargs: Additional attributes for the d_library rule.
    """
    exports_hdrs = []
    new_generated_srcs = {}
    new_generated_srcs |= generated_srcs
    for exp in exports:
        if not exp.endswith(".d"):
            fail("Exported files must be D source files, got: %s" % exp)
        hdr = name + ".hdrgen/" + exp + "_hdrgen"
        d_header_generator(
            name = hdr,
            src = exp,
        )
        if exp in generated_srcs:
            # If the file is already in generated_srcs, let's put di file next to the target d file.
            target =  generated_srcs[exp]
        else:
            target = exp
        exports_hdrs.append(hdr)
        di_name = target[:-2] + ".di"  # Replace .d with .di
        new_generated_srcs[hdr] = di_name

    if not test:
        d_library(
            name = name,
            srcs = srcs,
            imports = imports,
            string_imports = string_imports,
            data = data,
            linkopts = linkopts,
            versions = versions,
            hdrs = hdrs + exports_hdrs,
            exports = exports_no_hdrs,
            deps = deps,
            implementation_deps = implementation_deps,
            include_workspace_root = include_workspace_root,
            is_generated = is_generated,
            generated_srcs = new_generated_srcs,
            **kwargs,
        )
    else:
        d_test_library(
            name = name,
            srcs = srcs,
            imports = imports,
            string_imports = string_imports,
            data = data,
            linkopts = linkopts,
            versions = versions,
            hdrs = hdrs + exports_hdrs,
            exports = exports_no_hdrs,
            deps = deps,
            implementation_deps = implementation_deps,
            include_workspace_root = include_workspace_root,
            is_generated = is_generated,
            generated_srcs = new_generated_srcs,
            **kwargs,
        )

    if exports_lib:
        # Create a d_source_library with the exported files.
        d_library(
            name = exports_lib,
            hdrs = hdrs + exports_hdrs + exports_no_hdrs,
            imports = imports,
            string_imports = string_imports,
            data = data,
            linkopts = linkopts,
            versions = versions,
            include_workspace_root = include_workspace_root,
            is_generated = is_generated,
            generated_srcs = new_generated_srcs,
            **kwargs,
        )
