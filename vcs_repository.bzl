vcs_env_vars = ["VCS_HOME", "LM_LICENSE_FILE"]

def _vcs_repository_impl(ctx):
    environ = ctx.os.environ
    for var in vcs_env_vars:
        if not var in environ:
            environ[var] = None

    ctx.symlink(environ["VCS_HOME"], "vcs")
    ctx.symlink(environ["UVM_HOME"], "uvm")

    ctx.file("WORKSPACE", "")
    BUILD = """
load("@meru//:data_provider.bzl", "data_provider")
data_provider(name="vcs_env", data={{{}}}, visibility=["//visibility:public"])
exports_files(["vcs", "uvm"])
""".format(
        ",".join(
            ["\"{}\":\"{}\"".format(key,environ[key]) for key in vcs_env_vars]
        )
    )

    ctx.file("BUILD", BUILD)

vcs_repository = repository_rule(
    implementation = _vcs_repository_impl,
    environ = ["UVM_HOME"] + vcs_env_vars,
    configure = True,
    local = True
)