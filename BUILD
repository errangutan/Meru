load("//:config.bzl", "random_seed")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

random_seed(
    name = "random_seed",
    build_setting_default = False,
)

bzl_library(
    name = "meru",
    srcs = [
        "meru.bzl",
        "config.bzl"
    ],
    deps = [
        "@bazel_skylib//lib:paths"
    ]
)