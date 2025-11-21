package(default_visibility = ["//visibility:public"])

platform(
    name = "dmd",
    parents = ["@local_config_platform//:host"],
    constraint_values = [
        "//d/constraints/compiler:dmd",
    ],
)

platform(
    name = "ldc",
    parents = ["@local_config_platform//:host"],
    constraint_values = [
        "//d/constraints/compiler:ldc",
    ],
)

platform(
    name = "weka-ldc",
    parents = ["@local_config_platform//:host"],
    constraint_values = [
        "//d/constraints/compiler:weka-ldc",
    ],
)

platform(
    name = "weka-ldc-linux-x86_64",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
        "//d/constraints/compiler:weka-ldc",
    ],
)
