def _configure_local_paths_impl(repository_ctx):
    
    # Create struct params formatted as var_name = $VAR, ...
    environ = repository_ctx.os.environ
    paths_struct_content = ""
    for var in repository_ctx.attr._environ:
        paths_struct_content += "{} = {},".format(
            var.lower(),
            # If expected env var not set, set the value in struct to None
            "\""+environ[var]+"\"" if var in environ else "None")

    # Save struct values in struct called paths.
    paths_content = "local_paths = struct({})".format(paths_struct_content)
    repository_ctx.file("local_paths.bzl", content = paths_content)
    
    # Write BUILD file, so repo will be accessabe as package
    repository_ctx.file("BUILD", content = "")

local_paths = repository_rule(
    doc = "Creates repository for local_paths struct.",
    implementation = _configure_local_paths_impl,
    local = True,
    configure = True,
    environ = [
        "VCS_HOME",
        "VCS_LICENSE",
    ],
)