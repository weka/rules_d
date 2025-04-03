load("//d:repositories.bzl", "rules_d_toolchains")

def _non_module_dependencies_impl(_ctx):
    rules_d_toolchains()

non_module_dependencies = module_extension(implementation = _non_module_dependencies_impl)
