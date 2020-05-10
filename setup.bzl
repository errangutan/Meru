load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("vcs_repository.bzl", "vcs_repository")

def meru_setup():
    """Sets up meru dependencies
    
    Once meru_dependencies is called, the workspace calling meru
    must run this funciton in order to set up dependencies of meru.
    """
    bazel_skylib_workspace()
    vcs_repository(name="vcs")    
    