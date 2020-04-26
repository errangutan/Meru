load("@bazel_skylib//lib:paths.bzl", "paths")

def _file_group(name, srcs):
    return """
filegroup(
    name = "{}",
    srcs = {},
    visibility = ["//visibility:public"]
)
""".format(name, srcs)

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
    ctx.symlink(environ["UVM_HOME"], "uvm")

    _local_paths(ctx)

    ctx.file("WORKSPACE", "")
    BUILD_components = [
        _file_group("vlogan_runfiles", ["vcs/etc/uvm/uvm_macros.svh"]),
        """exports_files(["vcs", "uvm", "uvm/uvm_pkg.sv", "vcs/bin/vlogan", "vcs/bin/vcs"])"""
    ]

    # Write BUILD file, so repo will be accessabe as package
    ctx.file("BUILD", content = "\n".join(BUILD_components))

vcs_repository = repository_rule(
    implementation = _vcs_repository_impl,
    environ = [
        "UVM_HOME",
        "VCS_HOME",
        "LM_LICENSE_FILE",
    ],
    configure = True,
    local = True
)