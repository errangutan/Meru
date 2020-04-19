load("@bazel_skylib//lib:paths.bzl", "paths")

def _file_group(name, srcs):
    return """
filegroup(
    name = "{}",
    srcs = {},
    visibility = ["//visibility:public"]
)
    \n""".format(name, srcs)

def _local_paths(ctx):
    
    # Create struct params formatted as var_name = $VAR, ...
    environ = ctx.os.environ
    paths_struct_content = ""
    for var in ctx.attr._environ:
        paths_struct_content += "{} = {},".format(
            var.lower(),
            # If expected env var not set, set the value in struct to None
            "\""+environ[var]+"\"" if var in environ else "None")

    # Save struct values in struct called paths.
    paths_content = "local_paths = struct({})".format(paths_struct_content)
    ctx.file("local_paths.bzl", content = paths_content)

def _vcs_repository_impl(ctx):
    environ = ctx.os.environ

    ctx.symlink(environ["VCS_HOME"], "vcs")

    _local_paths(ctx)

    ctx.file("BUILD", "")
    ctx.file("WORKSPACE", "")

    # Write BUILD file, so repo will be accessabe as package
    ctx.file("BUILD", content = _file_group("vlogan", ["vcs/bin/vlogan"]))

vcs_repository = repository_rule(
    implementation = _vcs_repository_impl,
    environ = [
        "VCS_HOME",
        "VCS_LICENSE"
    ],
    configure = True,
    local = True
)