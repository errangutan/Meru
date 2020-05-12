load("@bazel_skylib//lib:paths.bzl", "paths")
load("//:data_provider.bzl", "Data")
load("//:config.bzl", "RandomSeedProvider", "SeedProvider")

BlockInfo = provider(
    doc = """Provides structure of source files for compiling a block.""",
    fields = {
        "vlog_files": 
        """A depset of SystemVerilog / Verilog files, required
        to build the target.""",

        "vhdl_files": """A depset of VHDL files.required
        to build the target.""",
    }
)

def _block_impl(ctx):
    """Implementation of the `block` rule.

    Creates a `BlockInfo` provider by accessing the `BlockInfo`
    providers of dependencies in the `blocks` attribute, and merges
    them into a single `BlockInfo` provider, while adding the source
    files of the current block. 
    """

    # Accumulate all file types into their depsets
    vlog_files = depset(
        transitive = [block[BlockInfo].vlog_files for block in ctx.attr.blocks] + 
        [label.files for label in ctx.attr.vlog_files]
    )

    vhdl_files = depset(
        transitive = [block[BlockInfo].vhdl_files for block in ctx.attr.blocks] + 
        [label.files for label in ctx.attr.vhdl_files]
    )

    return BlockInfo(
        vlog_files = vlog_files,
        vhdl_files = vhdl_files,
    )

block = rule(
    doc = "Gathers source files of a block ands it's dependencies.",
    implementation = _block_impl,
    attrs = {
        "vlog_files" : attr.label_list(
            doc = "List of .sv files",
            default = [],
            allow_files = [".sv", ".v"],
        ),
        "vhdl_files" : attr.label_list(
            doc = "List fo .vhdl files.",
            default = [],
            allow_files = [".vhd"],
        ),
        "blocks" : attr.label_list(
            doc = "List of blocks this block depends on.",
            default = [],
            allow_files = False,
            providers = [BlockInfo],
        ),
    },
    provides = [BlockInfo]
)

test_attrs = {
        "top" : attr.string(
            doc = "Name of top level module.",
            mandatory = True,
        ),
        "vlog_top" : attr.label(
            doc = """`.v` / `.sv` file which contains the top level module declared
             in `top`. `vlog_top` and `vhdl_top` are mutually exclusive.""",
            allow_single_file = [".sv", ".v"],
        ),
        "vhdl_top" : attr.label(
            doc = """`.vhd` file which contains the top level module declared in
            `top`. `vlog_top` and `vhdl_top` are mutually exclusive.""",
            allow_single_file = [".hdl"],
        ),
        "blocks" : attr.label_list(
            default = [],
            doc = """List of blocks this test depends on. Any target which provides
            a `BlockInfo` provider can be in this list.""",
            allow_files = False,
            providers = [BlockInfo],
        ),
        "data" : attr.label_list(
            doc = "Runtime dependencies of this test.",
            default = [],
        ),
        "defines" : attr.string_dict(
            doc = "Compiler defines. Formatted as string keyed dict of strings.",
            default = {},
        ),
        "timescale" : attr.string(
            doc = "Sets the `timescale` flag in elaboration.",
            default = "1ns/1ns",
        ),
        "seed" : attr.int(
            doc = """The seed to run this simulation test with. Is overridden by setting
            `@meru//:random_seed` or `@meru//:seed`.""",
            default = 1,
        ),
        "_random_seed" : attr.label(
            doc = """Causes the test to be run with a random seed. This is a build setting
            which is to be set on the command line""",
            default = "@meru//:random_seed",
        ),
        "_seed" : attr.label(
            doc = """Causes the test to be run with the provided seed. This is a build setting
            which is to be set on the command line""",
            default = "@meru//:seed",
        ),
        "_uvm" : attr.label(
            default = "@vcs//:uvm",
            allow_single_file = True
        ),
        "_vcs" : attr.label(
            default = "@vcs//:vcs",
            allow_single_file = True
        ),
        "_vcs_env" : attr.label(
            default = "@vcs//:vcs_env"
        ),
    }

def _test_impl(ctx):

    vcs_env = ctx.attr._vcs_env[Data].data

    has_vlog_top = ctx.file.vlog_top != None
    has_vhdl_top = ctx.file.vhdl_top != None

    if has_vlog_top and has_vhdl_top:
        fail("vlog_top and vhdl_top are mutually exclusive, pick one.")

    if not (has_vhdl_top or has_vlog_top):
        fail("No top file assigned. Assign vlog_top or vhdl_top.")

    # Merge depsets of dependencies into single depset, and add top file
    vlog_files = depset(
        [ctx.file.vlog_top] if has_vlog_top else [],
        transitive = [block[BlockInfo].vlog_files for block in ctx.attr.blocks]
    )
    
    vhdl_files = depset(
        [ctx.file.vhdl_top] if has_vhdl_top else [],
        transitive = [block[BlockInfo].vhdl_files for block in ctx.attr.blocks]
    )

    # Create define arguments. Each arg is formatted as +define+NAME=VALUE
    # if value is "", the arg format is +define+NAME
    vlog_defines_args = ctx.actions.args()
    for define_name, value in ctx.attr.defines.items():
        vlog_defines_args.add("+define+{define_name}{value}".format(
            define_name = define_name,
            value = "=%s" % value if value != "" else ""
        ))

    work_dir_path = paths.join(ctx.attr.name, "work")

    synopsys_sim_setup = ctx.actions.declare_file("%s_synopsys_sim.setup" % ctx.attr.name)
    ctx.actions.write(synopsys_sim_setup, "WORK > DEFAULT\nDEFAULT : ./%s" % paths.join(ctx.bin_dir.path, ctx.label.package,work_dir_path))

    vcs_env_dict = {
        "VCS_HOME"           : vcs_env.VCS_HOME,
        "HOME"               : "/dev/null",
        "SYNOPSYS_SIM_SETUP" : synopsys_sim_setup.path,
        "LM_LICENSE_FILE"    : vcs_env.LM_LICENSE_FILE,
        "PATH"               : "/usr/bin:/bin",
    }

    analysis_outputs = []

    if vlog_files: # If vlog files depset is not 
        vlog_args = ctx.actions.args()
        vlog_args.add_all([
            "-full64",
            "-nc",
            "+incdir+%s" % paths.join(ctx.file._uvm.path),
            paths.join(ctx.file._uvm.path, "uvm_pkg.sv"),
            "-ntb_opts","uvm",
            "-sverilog",
        ])

        # Create vlog files arguments.
        vlog_files_args = ctx.actions.args()
        vlog_files_args.add_all(vlog_files)

        AN_DB_dir = ctx.actions.declare_directory(paths.join(work_dir_path, "AN.DB"))
        analysis_outputs.append(AN_DB_dir)

        ctx.actions.run_shell(
            inputs = depset(
                [
                    ctx.file._uvm,
                    ctx.file._vcs,
                    synopsys_sim_setup,
                ],
                transitive=[vlog_files]),
            outputs = [AN_DB_dir],
            command = "{vlogan} $@".format(vlogan = paths.join(ctx.file._vcs.path, "bin/vlogan")),
            arguments = [vlog_args, vlog_defines_args, vlog_files_args],
            env = vcs_env_dict,
            mnemonic = "Vlogan",
            progress_message = "Analysing verilog files.",
        )

    if vhdl_files: # If vhdl_files depset is not empty
        vhdlan_args = ctx.actions.args()
        vhdlan_args.add_all([
            "-nc",
            "-full64"
        ])
        vhdl_files_args = ctx.actions.args()
        vhdl_files_args.add_all(vhdl_files)
        vhdl_andb_dir = ctx.actions.declare_directory(paths.join(work_dir_path, "64"))
        analysis_outputs.append(vhdl_andb_dir)

        ctx.actions.run_shell(
            inputs = depset(
                [
                    ctx.file._vcs,
                    synopsys_sim_setup,
                ],
                transitive=[vhdl_files]),
            outputs = [vhdl_andb_dir],
            command = "{vhdlan} $@".format(vhdlan = paths.join(ctx.file._vcs.path, "bin/vhdlan")),
            arguments = [vhdlan_args, vhdl_files_args],
            env = vcs_env_dict,
            mnemonic = "Vhdlan",
            progress_message = "Analysing vhdl files.",
        )

    # simv is created with a name unique to the target.
    # if the name is not unique, different targets under the same package
    # which are built concurrently will collide. 
    simv_file_name = "%s_simv" % ctx.attr.name
    simv = ctx.actions.declare_file(simv_file_name)
    daidir = ctx.actions.declare_directory("%s.daidir" % simv_file_name)

    elab_args = ctx.actions.args()
    elab_args.add_all([
        "-full64",
        "-timescale=%s" % ctx.attr.timescale,
        "-CFLAGS",
        "-DVCS",
        "-debug_access+all",
        paths.join(ctx.file._uvm.path, "dpi/uvm_dpi.cc"),
        "-j1",
        ctx.attr.top,
        "-o", simv,
    ])

    command = "{vcs} $@".format(vcs = paths.join(ctx.file._vcs.path, "bin/vcs"))

    ctx.actions.run_shell(
        outputs = [simv, daidir],
        inputs = analysis_outputs + [
            ctx.file._vcs,
            ctx.file._uvm,
            synopsys_sim_setup,
        ],
        command = command,
        arguments = [elab_args],
        env = vcs_env_dict,
    )

    random_seed_setting = ctx.attr._random_seed[RandomSeedProvider].value
    seed_setting = ctx.attr._seed[SeedProvider].value

    if random_seed_setting and seed_setting != -1:
        fail("@meru//:random_seed and @meru//:seed are mutually exclusive, choose only one.")
    
    if random_seed_setting:
        seed = "$RANDOM"
    elif seed_setting != -1:
        seed = str(seed_setting)
    else:
        seed = str(ctx.attr.seed)

    test_run_script = ctx.actions.declare_file("run_%s" % ctx.attr.name)
    ctx.actions.write(test_run_script, content="""
#!/bin/bash
cd {package} &&
{simv} -exitstatus +ntb_random_seed={seed} $@
    """.format(
        package=ctx.label.package,
        simv=simv_file_name,
        target_name=ctx.attr.name,
        seed = seed))

    return [DefaultInfo(
        executable=test_run_script,
        runfiles=ctx.runfiles(files = [simv, daidir])
    )]

sim_test = rule(
    doc = "Runs a test.",
    implementation = _test_impl,
    attrs = test_attrs,
    test = True,
)

testbench = rule(
    doc = "Testbench. Identical to `sim_test` but is not regarded as a test.",
    implementation = _test_impl,
    attrs = test_attrs,
)

def _regression_test_sanity_check(kwargs):
    """Asserts that `defines` parameter is given, and is a string keyed dict of lists of strings"""

    if "name" not in kwargs:
        fail("Missing name parameter.")

    if type(kwargs["name"]) != type(""):
        fail("Expected type string for name parameter, got %s" % type(kwargs["name"]))

    if "defines" not in kwargs:
        fail("The defines paramter is mandatory. Add the defines of the regression.")

    defines = kwargs["defines"]

    if type(defines) != type({}):
        fail("Expected type dict for defines paramter, got %s." % type(defines))

    for define_name, value_options in defines.items():
        if type(define_name) != type(""):
            fail("Expected type string for key in defines dictionary, got %s." % type(define_name))
        if type(value_options)!= type([]):
            fail("Expected type list for value in defines dictionary, got %s." % type(value_options))
        for value in value_options:
            if type(value) != type("") and type(value) != type(None):
                fail("Expected type string or None for item in list in defines dictionary, got %s" % type(value))
    
def _get_defines_permutations(defines_options_dict):
    """
    Returns a list of all permutations between defines options.
    This can be described as icrementing a counter, where
    every digit is a define name: <define_n-1>...<define_1><define_0>
    each digit has a different base, which is the number of options
    of that define name. We stop incrementing once we reach the highest
    "number" which can be represented by the counter.
    """

    num_of_permutations = 1
    for key, options_list in defines_options_dict.items():
        num_of_permutations *= len(options_list)
    
    # Initiate the counter to 0
    indexes = {key : 0 for key in defines_options_dict}
    
    permutations = []
    for i in range(num_of_permutations):
        carry = True
    
        for key in defines_options_dict:
            if carry == True:
                carry = True if indexes[key] == len(defines_options_dict[key]) - 1 else False 
                indexes[key] = (indexes[key] + 1) % len(defines_options_dict[key])
    
        permutations.append({key: defines_options_dict[key][indexes[key]] for key in defines_options_dict if defines_options_dict[key][indexes[key]] != None})

    return permutations

def _get_dict_copy(d):
    return {k:v for k,v in d.items()}

def regression_test(**kwargs):
    """Runs a regression test.
    
    This macro creates `sim_test` targets for every permutation of defines,
    and a test suite which includes them all.

    Args:
        name: A unique name for the test suite.
        defines: A `string`-keyed `dict` of `list`s of `string`s, where each key
            is a define name, and its associated list is its possible values. If a possible
            value of a define is having no value, add an empty string to the list.
            If a possible value is having the define not be defines at all, add `None` to
            the list.
        **kwargs: The rest of the parameters will simply be passed the the sim_test
            targets.
    """

    _regression_test_sanity_check(kwargs)

    defines_permutations = _get_defines_permutations(kwargs["defines"])

    test_list = []

    # For every permutation, create a test. The target name of each test
    # is the name kwarg + i, where i is the index of the test permutation in
    # the permutations list.
    for i,defines in enumerate(defines_permutations):
        sim_test_kwargs = _get_dict_copy(kwargs)
        sim_test_kwargs["defines"] = defines
        sim_test_kwargs["name"] = "%s_%d" % (kwargs["name"], i)
        test_list.append(sim_test_kwargs["name"])
        sim_test(**sim_test_kwargs)

    # Create a test suite to call all of the tests under single label.
    native.test_suite(
        name = kwargs["name"],
        tests = test_list
    )