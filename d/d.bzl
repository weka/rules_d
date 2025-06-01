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

def _is_windows(ctx):
    return ctx.configuration.host_path_separator == ";"

def a_filetype(ctx, files):
    lib_suffix = ".lib" if _is_windows(ctx) else ".a"
    return [f for f in files if f.basename.endswith(lib_suffix)]

D_FILETYPE = [".d", ".di", ".h"] # TODO: restrict support of .di and .h files to source libraries

ZIP_PATH = "/usr/bin/zip"

DInfo = provider()

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

def _compilation_mode_flags(ctx):
    """Returns a list of flags based on the compilation_mode."""
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
    return (
        _compilation_mode_flags(ctx) +
        extra_flags + [
            "-of" + out.path,
            "-w",
        ] +
        (["-I%s" % ws_root] if ctx.attr.include_workspace_root else []) +
        ["-I%s" % im for im in depinfo.imports] +
        ["-J%s" % im for im in depinfo.string_imports] +
        # toolchain.import_flags +
        [version_flag + "=%s" % v for v in depinfo.versions.to_list()]
    )

def _build_link_arglist(ctx, objs, out, depinfo, c_compiler, link_flags):
    """Returns a list of strings constituting the D link command arguments."""
    return (
        _compilation_mode_flags(ctx) +
        (["-gcc=%s" % c_compiler.files.to_list()[0].path] if c_compiler else []) +
        (link_flags or []) +
        ["-of" + out.path] +
        [f.path for f in depset(transitive = [depinfo.libs, depinfo.transitive_libs]).to_list()] +
        depinfo.link_flags +
        objs
    )

def _setup_deps(ctx, deps, name):
    """Sets up dependencies.

    Walks through dependencies and constructs the commands and flags needed
    for linking the necessary dependencies.

    Args:
      ctx: The context of the current target.
      deps: List of deps labels from ctx.attr.deps.
      name: Name of the current target.

    Returns:
      Returns a struct containing the following fields:
        libs: List of Files containing the target's direct library dependencies.
        transitive_libs: List of Files containing all of the target's
            transitive libraries.
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
        extra_files: List of Files containing extra (non-source) files that will
            be used as inputs for this target.
    """

    gen_dir = ctx.genfiles_dir.path
    libs = []
    transitive_libs = []
    d_srcs = []
    extra_files = []
    transitive_d_srcs = []
    transitive_extra_files = []
    versions = ctx.attr.versions + ["Have_%s" % _format_version(name)]
    transitive_versions = []
    gen_dir_for_imports = gen_dir if ctx.attr.is_generated else None
    imports = [_build_import(ctx.label, im, gen_dir_for_imports) for im in ctx.attr.imports]
    string_imports = [_build_import(ctx.label, im, gen_dir_for_imports) for im in ctx.attr.string_imports]
    link_flags = []
    generated_srcs = {
        src.files.to_list()[0]: src.label.package + "/" + loc for src, loc in ctx.attr.generated_srcs.items()}
    for dep in deps:
        if DInfo in dep and hasattr(dep[DInfo], "d_lib"):
            # The dependency is a d_library.
            ddep = dep[DInfo]
            libs.append(ddep.d_lib)
            transitive_libs.append(ddep.transitive_libs)
            d_srcs += ddep.d_exports
            transitive_d_srcs.append(ddep.transitive_d_srcs)
            extra_files += ddep.extra_files
            transitive_extra_files.append(ddep.transitive_extra_files)
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
            extra_files += ddep.extra_files
            transitive_extra_files.append(ddep.transitive_extra_files)
            transitive_libs.append(ddep.transitive_libs)
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
            transitive_libs.append(depset(native_libs))

        else:
            fail("D targets can only depend on d_library, d_source_library, or " +
                 "cc_library targets.", dep)

    return struct(
        libs = depset(libs),
        transitive_libs = depset(transitive = transitive_libs),
        transitive_d_srcs = depset(d_srcs, transitive = transitive_d_srcs),
        extra_files = depset(extra_files).to_list(),
        transitive_extra_files = depset(transitive = transitive_extra_files),
        versions = depset(versions, transitive = transitive_versions),
        imports = depset(imports).to_list(),
        string_imports = depset(string_imports).to_list(),
        link_flags = depset(link_flags).to_list(),
        generated_srcs = generated_srcs,
    )

def _handle_generated_srcs(ctx, generated_srcs, d_compiler):
    """Handles the generated source files."""
    if not generated_srcs:
        return (ctx.files.srcs, None)
    mapped_srcs = [src if src not in generated_srcs else generated_srcs[src] for src in ctx.files.srcs]

    generated_srcs_file = ctx.actions.declare_file(ctx.label.name + "_generated_srcs_wrapper.sh")
    ctx.actions.write(
        output = generated_srcs_file,
        content = "\n".join(
            [
                "#!/bin/sh",
                "set -e",
            ] + 
            [
                "mkdir -p $(dirname %s)\n" % loc +
                "ln -s $PWD/%s %s" % (src.path, loc) for src, loc in generated_srcs.items()
            ] + [
                "%s $*" % d_compiler.path,
            ]),
        is_executable = True,
    )

    return (mapped_srcs, generated_srcs_file)

def _d_library_impl_common(ctx, extra_flags = []):
    """Implementation of the d_library rule."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    #d_lib = ctx.actions.declare_file((ctx.label.name + ".lib") if _is_windows(ctx) else ("lib" + ctx.label.name + ".a"))
    d_lib = ctx.actions.declare_file(ctx.label.name + ".o")
    d_compiler = toolchain.d_compiler.files.to_list()[0]

    # Dependencies
    deps = ctx.attr.deps + ([toolchain.libphobos] if toolchain.libphobos != None else []) + ([toolchain.druntime] if toolchain.druntime != None else [])
    depinfo = _setup_deps(ctx, ctx.attr.deps, ctx.label.name)

    # Build compile command.
    compile_args = _build_compile_arglist(
        ctx = ctx,
        out = d_lib,
        depinfo = depinfo,
        extra_flags = ["-c"] + extra_flags,
    )

    # Convert sources to args
    # This is done to support receiving a File that is a directory, as
    # args will auto-expand this to the contained files
    args = ctx.actions.args()
    args.add_all(compile_args)

    mapped_srcs, generated_srcs_wrapper = _handle_generated_srcs(ctx, depinfo.generated_srcs, d_compiler)

    args.add_all(mapped_srcs)

    phobos_files = toolchain.libphobos.files if toolchain.libphobos != None else depset()
    phobos_src_files = toolchain.libphobos_src.files if toolchain.libphobos_src != None else depset()
    druntime_src_files = toolchain.druntime_src.files if toolchain.druntime_src != None else depset()
    # TODO: Should they be in transitive?
    compile_inputs = depset(
        ctx.files.srcs +
        ctx.files.hdrs +
        ctx.files.exports +
        ctx.files.extra_files +
        depinfo.extra_files,
        transitive = [
            depinfo.transitive_d_srcs,
            depinfo.transitive_extra_files,
            depinfo.libs,
            depinfo.transitive_libs,
            phobos_files,
            phobos_src_files,
            druntime_src_files,
        ],
    )

    ctx.actions.run(
        inputs = compile_inputs,
        tools = [d_compiler, generated_srcs_wrapper] if generated_srcs_wrapper else [d_compiler],
        outputs = [d_lib],
        mnemonic = "Dcompile",
        executable = generated_srcs_wrapper if generated_srcs_wrapper else d_compiler,
        arguments = [args],
        use_default_shell_env = True,
        progress_message = "Compiling D library " + ctx.label.name,
    )

    public_srcs = ctx.files.hdrs + ctx.files.exports
    if not public_srcs:
        public_srcs = ctx.files.srcs

    return [
        DefaultInfo(
            files = depset([d_lib]),
        ),
        DInfo(
            d_srcs = ctx.files.srcs,
            d_exports = public_srcs,
            transitive_d_srcs = depinfo.transitive_d_srcs,
            extra_files = ctx.files.extra_files,
            transitive_extra_files = depset(depinfo.extra_files),
            transitive_libs = depset(transitive = [depinfo.libs, depinfo.transitive_libs]),
            link_flags = depinfo.link_flags,
            linkopts = ctx.attr.linkopts,
            versions = depinfo.versions,
            imports = depinfo.imports,
            string_imports = depinfo.string_imports,
            d_lib = d_lib,
            is_generated = ctx.attr.is_generated,
            generated_srcs = depinfo.generated_srcs,
        ),
    ]

def _d_binary_impl_common(ctx, extra_flags = []):
    """Common implementation for rules that build a D binary."""
    toolchain = ctx.toolchains[D_TOOLCHAIN]
    d_bin = ctx.actions.declare_file(ctx.label.name + ".exe" if _is_windows(ctx) else ctx.label.name)
    d_obj = ctx.actions.declare_file(ctx.label.name + (".obj" if _is_windows(ctx) else ".o"))
    d_compiler = toolchain.d_compiler.files.to_list()[0]

    # Dependencies
    deps = ctx.attr.deps + ([toolchain.libphobos] if toolchain.libphobos != None else []) + ([toolchain.druntime] if toolchain.druntime != None else [])
    depinfo = _setup_deps(ctx, deps, ctx.label.name)

    # Build compile command
    compile_args = _build_compile_arglist(
        ctx = ctx,
        depinfo = depinfo,
        out = d_obj,
        extra_flags = ["-c"] + extra_flags,
    )

    # Convert sources to args
    # This is done to support receiving a File that is a directory, as
    # args will auto-expand this to the contained files
    args = ctx.actions.args()
    args.add_all(compile_args)

    mapped_srcs, generated_srcs_wrapper = _handle_generated_srcs(ctx, depinfo.generated_srcs, d_compiler)

    args.add_all(mapped_srcs)

    toolchain_files = [
        toolchain.libphobos.files if toolchain.libphobos != None else depset(),
        toolchain.libphobos_src.files if toolchain.libphobos_src != None else depset(),
        toolchain.druntime_src.files if toolchain.druntime_src != None else depset(),
    ]

    compile_inputs = depset(
        ctx.files.srcs + ctx.files.extra_files + depinfo.extra_files,
        transitive = [depinfo.transitive_d_srcs, depinfo.transitive_extra_files] + toolchain_files,
    )
    ctx.actions.run(
        inputs = compile_inputs,
        tools = [d_compiler, generated_srcs_wrapper] if generated_srcs_wrapper else [d_compiler],
        outputs = [d_obj],
        mnemonic = "Dcompile",
        executable = generated_srcs_wrapper if generated_srcs_wrapper else d_compiler,
        arguments = [args],
        use_default_shell_env = True,
        progress_message = "Compiling D binary " + ctx.label.name,
    )

    # Build link command
    link_args = _build_link_arglist(
        ctx = ctx,
        objs = [d_obj.path],
        depinfo = depinfo,
        out = d_bin,
        c_compiler = toolchain.c_compiler,
        link_flags = toolchain.link_flags,
    )

    link_inputs = depset(
        [d_obj],
        transitive = [depinfo.libs, depinfo.transitive_libs] + toolchain_files,
    )

    ctx.actions.run(
        inputs = link_inputs,
        tools = [d_compiler] + (toolchain.c_compiler.files.to_list() if toolchain.c_compiler else []),
        outputs = [d_bin],
        mnemonic = "Dlink",
        executable = d_compiler,
        arguments = link_args,
        use_default_shell_env = True,
        progress_message = "Linking D binary " + ctx.label.name,
    )

    return [
        DInfo(
            d_srcs = ctx.files.srcs,
            transitive_d_srcs = depinfo.transitive_d_srcs,
            extra_files = ctx.files.extra_files,
            transitive_extra_files = depset(depinfo.extra_files),
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
    transitive_extra_files = []
    transitive_libs = []
    transitive_transitive_libs = []
    transitive_imports = depset()
    transitive_string_imports = depset()
    transitive_linkopts = depset()
    transitive_versions = depset()
    for dep in ctx.attr.deps:
        if DInfo in dep and hasattr(dep[DInfo], "d_srcs") and not hasattr(dep[DInfo], "d_lib"):
            # Dependency is another d_source_library target.
            # TODO: Could we also support d_library here?
            ddep = dep[DInfo]
            transitive_d_srcs.append(depset(ddep.d_srcs, transitive = [ddep.transitive_d_srcs]))
            transitive_extra_files.append(depset(ddep.extra_files))
            transitive_imports = depset(ddep.imports, transitive = [transitive_imports])
            transitive_string_imports = depset(ddep.string_imports, transitive = [transitive_string_imports])
            transitive_linkopts = depset(ddep.linkopts, transitive = [transitive_linkopts])
            transitive_versions = depset(transitive = [ddep.versions, transitive_versions])
            transitive_transitive_libs.append(ddep.transitive_libs)

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
            extra_files = ctx.files.extra_files,
            transitive_d_srcs = depset(transitive = transitive_d_srcs, order = "postorder"),
            transitive_extra_files = depset(transitive = transitive_extra_files, order = "postorder"),
            transitive_libs = depset(transitive_libs, transitive = transitive_transitive_libs),
            imports = [_build_import(ctx.label, im, gen_dir) for im in ctx.attr.imports] + transitive_imports.to_list(),
            string_imports = [_build_import(ctx.label, im, gen_dir) for im in ctx.attr.string_imports] + transitive_string_imports.to_list(),
            linkopts = ctx.attr.linkopts + transitive_linkopts.to_list(),
            versions = depset(ctx.attr.versions, transitive = [transitive_versions]),
            is_generated = ctx.attr.is_generated,
            generated_srcs = ctx.attr.generated_srcs,
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
        tools = [d_compiler],
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
        tools = [d_compiler],
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
    "extra_files": attr.label_list(allow_files = True),
    "linkopts": attr.string_list(),
    "versions": attr.string_list(),
    "include_workspace_root": attr.bool(default = True),
    "is_generated": attr.bool(default = False),
    "generated_srcs": attr.label_keyed_string_dict(),
    "deps": attr.label_list(),
}

_d_library_attrs = {
    "hdrs": attr.label_list(allow_files = D_FILETYPE, allow_empty = True),
    "exports": attr.label_list(allow_files = D_FILETYPE),
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
    attrs = dict(_d_common_attrs.items()),
    executable = True,
    toolchains = [D_TOOLCHAIN],
)

d_test = rule(
    _d_test_impl,
    attrs = dict(_d_common_attrs.items()),
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
