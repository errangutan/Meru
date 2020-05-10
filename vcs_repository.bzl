
# List of environment variables which must be set in order to VCS
# to work correctly.
vcs_env_vars = ["VCS_HOME", "LM_LICENSE_FILE"]

def _vcs_repository_impl(ctx):
    environ = ctx.os.environ

    # Sanity check for environment variables.
    for var in vcs_env_vars:
        if not var in environ:
            fail("""{0} is required to run VCS but was not set. You can\
set the variable by adding the following line to the system-wide\
bazelrc file (/etc/bazel.bazelrc):\
build --action_env {0}=<value>""".format(var))

    # Create symlinks which will be exported
    ctx.symlink(environ["VCS_HOME"], "vcs")
    ctx.symlink(environ["UVM_HOME"], "uvm")

    ctx.file("WORKSPACE", "")
    BUILD = """
load("@meru//:data_provider.bzl", "data_provider")
data_provider(name="vcs_env", data={{{}}}, visibility=["//visibility:public"])
exports_files(["vcs", "uvm"])
""".format(",".join(["\"{}\":\"{}\"".format(key,environ[key]) for key in vcs_env_vars]))

    ctx.file("BUILD", BUILD)

vcs_repository = repository_rule(
    doc = """This rule initiates the VCS repository.
    
    The Meru workspace calls this repository rule uppon initializing. This
    repository gives Merus rules access to files associated with VCS,
    and provides the environment variables needed to run VCS via the `vcs_env`
    target.
    """,
    implementation = _vcs_repository_impl,
    environ = ["UVM_HOME"] + vcs_env_vars,
    configure = True,
    local = True
)