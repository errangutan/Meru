load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

stardoc(
    name = "meru-docs",
    input = "meru.bzl",
    out = "meru_doc.md",
    deps = [
        "@vcs//:bzl-lib",
        "@bazel_skylib//:lib",
    ],
)
