load("@bazel_json//lib:json_parser.bzl", "json_parse")
load("@vcs//:local_paths.bzl", "local_paths")
load("@bazel_skylib//lib:paths.bzl", "paths")

BlockInfo = provider(
    doc = """Provides structure of source files for compiling a dependency block""",
    fields = {
        "vlog_libs": 
        """A dictionary of SystemVerilog / Verilog files.
        The key of the dictionary is the name of a library,
        and the value is a list of source files that belong
        to that library.""",

        "vhdl_libs": """A dictionary of VHDL files.The key
        of the dictionary is the name of a library, and the
        value is a list of source files that belong to that
        library.""",

        "sdc_files": """A list of sdc files which are to be
        applied to a Quartus project which uses this block.
        """,
    }
)

def _get_transitive_libs(files, files_lib, dependecy_libs):
    """Merges between depsets of same library in different
    dependencies, adds `files` to the lib `files_lib`
    and returns the merged lib construct.

    Args:
        `files`: List of `File` objects
        `files_lib`: Name of library `files` belong to
        `dependency_libs`: List of library constructs which are to be merged to single library. 
    """

    # Get all lib names in side lib dicts
    libs = [files_lib]
    for lib_dict in dependecy_libs:
        libs.extend(lib_dict.keys())
    libs = [x for i,x in enumerate(libs) if x not in libs[:i]] # Remove doubles

    # For every library we found in the libs dicts, get all depsets of that library
    output_libs_dict = {}
    for lib in libs:
        output_libs_dict[lib] = depset(
            files if lib == files_lib else [],
            transitive=[lib_dict[lib] for lib_dict in dependecy_libs if lib in lib_dict]
            )

    return output_libs_dict

def _block_impl(ctx):
    """Implementation of the `block` rule.

    Creates a `BlockInfo` provider by accessing the `BlockInfo`
    providers of dependencies in the `blocks` attribute, and merges
    them into a single `BlockInfo` provider, while adding the source
    files of the current block. 
    """

    # Get flattened list of files from all files in the vlog_files targets.
    vlog_files = []
    for file_list in [target.files.to_list() for target in ctx.attr.vlog_files]:
        vlog_files += file_list 

    vhdl_files = []
    for file_list in [target.files.to_list() for target in ctx.attr.vhdl_files]:
        vhdl_files += file_list

    # Merge vlog_libs and vhdl_libs of dependencies, and add source files of this block
    vlog_libs = _get_transitive_libs(
        vlog_files,
        ctx.attr.lib,
        [block[BlockInfo].vlog_libs for block in ctx.attr.blocks])

    vhdl_libs = _get_transitive_libs(
        vhdl_files,
        ctx.attr.lib,
        [block[BlockInfo].vhdl_libs for block in ctx.attr.blocks])

    # Create depset from dependency sdc_files and add sdc files of this block
    sdc_files = depset(
        ctx.attr.sdc_files,
        transitive = [block[BlockInfo].sdc_files for block in ctx.attr.blocks])

    return BlockInfo(
        vlog_libs = vlog_libs,
        vhdl_libs = vhdl_libs,
        sdc_files = sdc_files,
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
            allow_files = [".vhdl"],
        ),
        "lib" : attr.string(
            doc = "Name of library of HDL files.",
            default = "work",
        ),
        "sdc_files" : attr.label_list(
            doc = "List of sdc files which are to be applied for PNR.",
            default = [],
            allow_files = [".sdc"],
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
            doc = "```.v``` / ```.sv``` file which contains the top level module declared in ```top```. ```vlog_top``` and ```vhdl_top``` are mutually exclusive.",
            allow_single_file = [".sv", ".v"],
        ),
        "vhdl_top" : attr.label(
            doc = "```.vhd``` file which contains the top level module declared in ```top```. ```vlog_top``` and ```vhdl_top``` are mutually exclusive.",
            allow_single_file = [".hdl"],
        ),
        "lib" : attr.string(
            doc = "Name of library of the top_file.",
            default = "work",
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
    }

def _test_impl(ctx): 

    has_vlog_top = ctx.file.vlog_top != None
    has_vhdl_top = ctx.file.vhdl_top != None

    if has_vlog_top and has_vhdl_top:
        fail("vlog_top and vhdl_top are mutually exclusive, pick one.")

    if not (has_vhdl_top or has_vlog_top):
        fail("No top file assigned. Assign vlog_top or vhdl_top.")

    # Merge libs of dependencies into single dict, and add top file
    vlog_libs = _get_transitive_libs(
        [ctx.file.vlog_top] if has_vlog_top else [],
        ctx.attr.lib,
        [block[BlockInfo].vlog_libs for block in ctx.attr.blocks])

    vhdl_libs = _get_transitive_libs(
        [ctx.file.vhdl_top] if has_vhdl_top else [],
        ctx.attr.lib,
        [block[BlockInfo].vhdl_libs for block in ctx.attr.blocks])

    # Create define arguments. Each arg is formatted as +define+NAME=VALUE
    # if value is "", the arg format is +define+NAME
    vlog_defines_args = ctx.actions.args()
    for define_name, value in ctx.attr.defines.items():
        vlog_defines_args.add("+define+{define_name}{value}".format(
            define_name = define_name,
            value = "=%s" % value if value != "" else ""
        ))

    out_dir = paths.join(ctx.bin_dir.path, ctx.label.package, ctx.attr.name)
    cd_path_fix = "/".join(len(out_dir.split("/"))*[".."])
    

    for lib_key, vlog_files in vlog_libs.items():

        vlog_args = ctx.actions.args()
        vlog_args.add_all([
            "-full64",
            "-work","WORK",
            "+incdir+%s" % paths.join(cd_path_fix, ctx.file._uvm.path),
            paths.join(cd_path_fix, ctx.file._uvm_pkg.path),
            "-ntb_opts","uvm",
            "-sverilog",
        ])

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

    command = "cd {out_dir}; pwd; {vcs} $@".format(
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

    run_simv = ctx.actions.declare_file("run_%s_simv" % ctx.attr.name)
    ctx.actions.write(run_simv, content="""
    #!/bin/bash 
    cd {package}/{target_name}
    {simv} -exitstatus $@
    """.format(package=ctx.label.package, simv=simv_file_name, target_name=ctx.attr.name))

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

    # Get the number of permutations in order to know how many
    # permutations to create
    num_of_permutations = 1

    for key, options_list in defines_options_dict.items():
        num_of_permutations *= len(options_list)
    
    indexes = {key : 0 for key in defines_options_dict}
    
    # Create all permutations between defines options
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
    _regression_test_sanity_check(kwargs)

    defines_permutations = _get_defines_permutations(kwargs["defines"])

    test_list = []

    print(defines_permutations)

    for i,defines in enumerate(defines_permutations):
        sim_test_kwargs = _get_dict_copy(kwargs)
        sim_test_kwargs["defines"] = defines
        sim_test_kwargs["name"] = "%s_%d" % (kwargs["name"], i)
        test_list.append(sim_test_kwargs["name"])
        sim_test(**sim_test_kwargs)

    native.test_suite(
        name = kwargs["name"],
        tests = test_list
    )

    

