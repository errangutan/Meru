load("@bazel_skylib//lib:paths.bzl", "paths")

def _file_group(name, files):
    return "filegroup(name = {}, files = {})\n".format(name, files)

def _vcs_repository_impl(ctx):
    environ = ctx.os.environ

    ctx.symlink(environ["VCS_HOME"], "vcs")

    ctx.symlink(environ["VCS_HOME"])
    
    ctx.file("BUILD", "")
    ctx.file("WORKSPACE", "")

    # Write BUILD file, so repo will be accessabe as package
    ctx.file("BUILD", content = "")

vcs_repository = repository_rule(
    implementation = _vcs_repository_impl
    environ = [
        "VCS_HOME",
        "VCS_LICENSE"
    ],
    configure = True,
    local = True
)