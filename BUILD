load("//:config.bzl", "random_seed", "seed")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

random_seed(
    name = "random_seed",
    build_setting_default = False,
)

seed(
    name = "seed",
    build_setting_default = -1,
)

bzl_library(
    name = "meru",
    srcs = [
        "meru.bzl",
        "config.bzl",
        "data_provider.bzl",
    ],
    deps = [
        "@bazel_skylib//lib:paths",
    ]
)