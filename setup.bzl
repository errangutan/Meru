load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("vcs_repository.bzl", "vcs_repository")

def meru_setup():
    bazel_skylib_workspace()
    vcs_repository(name="vcs")    
    