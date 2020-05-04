workspace(name = "meru")

load("//:repositories.bzl", "meru_dependencies")
meru_dependencies()
load("//:setup.bzl", "meru_setup")
meru_setup()

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "io_bazel_stardoc",
    remote = "https://github.com/bazelbuild/stardoc.git",
    tag = "0.4.0",
)

load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")
stardoc_repositories()