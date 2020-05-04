load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//:config.bzl", "random_seed")

random_seed(
    name = "random_seed",
    build_setting_default = False,
)

stardoc(
    name = "meru-docs",
    input = "meru.bzl",
    out = "meru_doc.md",
    deps = [
        "@vcs//:bzl-lib",
        "@bazel_skylib//:lib",
    ],
)