"""
Rules are for fools
"""

load("@vcs//:local_paths.bzl", "local_paths")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("//:config.bzl", "RandomSeedProvider")

BlockInfo = provider(
    doc = """Provides structure of source files for compiling a dependency block""",
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
            doc = "`.v` / `.sv` file which contains the top level module declared in `top`. `vlog_top` and `vhdl_top` are mutually exclusive.",
            allow_single_file = [".sv", ".v"],
        ),
        "vhdl_top" : attr.label(
            doc = "`.vhd` file which contains the top level module declared in `top`. `vlog_top` and `vhdl_top` are mutually exclusive.",
            allow_single_file = [".hdl"],
        ),
        "blocks" : attr.label_list(
            default = [],
            doc = "List of blocks this test depends on.",
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
            doc = "Elaboration timescale flag",
            default = "1ns/1ns",
        ),
        "_vlogan" : attr.label(
            default = "@vcs//:vcs/bin/vlogan",
            allow_single_file = True
        ),
        "_uvm" : attr.label(
            default = "@vcs//:uvm",
            allow_single_file = True
        ),
        "_vcs" : attr.label(
            default = "@vcs//:vcs/bin/vcs",
            allow_single_file = True
        ),
        "_uvm_pkg" : attr.label(
            default = "@vcs//:uvm/uvm_pkg.sv",
            allow_single_file = True
        ),
        "_random_seed" : attr.label(
            default = "@meru//:random_seed"
        ),
        "seed" : attr.int(
            default = 1
        )
    }

def _test_impl(ctx): 

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

    # Get the path where vlogan and vhdlan should pr run.
    # Once the output directory is resolved, get the relation
    # between the output directory and the source files root
    out_dir = paths.join(ctx.bin_dir.path, ctx.label.package, ctx.attr.name)
    cd_path_fix = "/".join(len(out_dir.split("/"))*[".."])

    vlog_args = ctx.actions.args()
    vlog_args.add_all([
        "-full64",
        "-work","WORK",
        "+incdir+%s" % paths.join(cd_path_fix, ctx.file._uvm.path),
        paths.join(cd_path_fix, ctx.file._uvm_pkg.path),
        "-ntb_opts","uvm",
        "-sverilog",
    ])

    # Create vlog files arguments. Each file must pre prepended with
    # the cd_path_fix, since thier path must be fixed once cd'ing into
    # the output directory.
    files_args = ctx.actions.args()
    files_args.add_all(vlog_files, format_each="{}/%s".format(cd_path_fix))

    AN_DB_dir = ctx.actions.declare_directory(paths.join(ctx.attr.name, "AN.DB"))

    ctx.actions.run_shell(
        inputs = depset(
            [ctx.file._uvm_pkg, ctx.file._vlogan],
            transitive=[vlog_files]),
        outputs = [AN_DB_dir],
        command = "cd {out_dir};{vlogan} $@".format(
            vlogan = paths.join(cd_path_fix, ctx.file._vlogan.path),
            out_dir = out_dir,
        ),
        arguments = [vlog_args, vlog_defines_args, files_args],
        env = {
            "VCS_HOME" : local_paths.vcs_home,
            "HOME" : "/dev/null",
            "UVM_HOME" : local_paths.uvm_home
        },
        mnemonic = "Vlogan",
        progress_message = "Analysing verilog files.",
    )

    # simv is created with a name unique to the target.
    # if the name is not unique, different targets under the same package
    # which are built concurrently will collide. 
    simv_file_name = "%s_simv" % ctx.attr.name
    simv = ctx.actions.declare_file(paths.join(ctx.attr.name, simv_file_name))
    
    elab_args = ctx.actions.args()
    elab_args.add_all([
        "-full64",
        "-timescale=%s" % ctx.attr.timescale,
        "-CFLAGS",
        "-DVCS",
        "-debug_access+all",
        paths.join(local_paths.uvm_home, "dpi/uvm_dpi.cc"),
        "-j1", ctx.attr.top,
        "-o", simv_file_name,
    ])

    command = "cd {out_dir}; {vcs} $@".format(
        vcs = paths.join(cd_path_fix, ctx.file._vcs.path),
        out_dir = out_dir,
    )

    daidir_path = ctx.actions.declare_directory(paths.join(ctx.attr.name, "%s.daidir" % simv_file_name))

    ctx.actions.run_shell(
        outputs = [simv, daidir_path],
        inputs = [AN_DB_dir, ctx.file._vcs, ctx.file._uvm],
        command = command,
        arguments = [elab_args],
        env = {
            "VCS_HOME" : local_paths.vcs_home,
            "LM_LICENSE_FILE" : local_paths.lm_license_file,
            "HOME" : "/dev/null",
            "PATH" : "/usr/bin:/bin",
        },
    )

    if ctx.attr._random_seed[RandomSeedProvider].value:
        seed = "$RANDOM"
    else:
        seed = str(ctx.attr.seed)

    run_simv = ctx.actions.declare_file("run_%s_simv" % ctx.attr.name)
    ctx.actions.write(run_simv, content="""
    #!/bin/bash 
    cd {package}/{target_name}
    {simv} -exitstatus +ntb_random_seed={seed} $@
    """.format(
        package=ctx.label.package,
        simv=simv_file_name,
        target_name=ctx.attr.name,
        seed = seed))

    return [DefaultInfo(
        executable=run_simv,
        runfiles=ctx.runfiles(files = [simv, daidir_path])
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
    """Asserts that defines parameter is given, and is a string keyed dict of lists of strings"""

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
    """
    Creates sim_test targets for every permutation of
    defines, and a test suite which includes them all.

    Args:
        `name`: A unique name for the test suite.
        
        `defines`: A `string`-keyed `dict` of `list`s of `string`s, where each key
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

    

