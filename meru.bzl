load("@bazel_json//lib:json_parser.bzl", "json_parse")
load("@vcs//:local_paths.bzl", "local_paths")
load("@bazel_skylib//lib:paths.bzl", "paths")

BlockInfo = provider(
    doc = "Provides sdc_files, and a libs dict. Each lib is a struct with a vlog_files depset and a vhdl_files depset.",
    fields = ["vlog_libs", "vhdl_libs", "sdc_files"]
)

RegsInfo = provider(
    doc = "Provides info about the findl"
)

def _get_transitive_libs(files, files_lib, dependecy_libs):
    """Merges between depsets of same library in different
    dependencies, adds ```files``` to the lib ```files_lib```
    and returns the merged lib construct.

    Args:
        ```files```: List of ```File``` objects
        ```files_lib```: Name of library ```files``` belong to
        ```dependency_libs```: List of library constructs which are to be merged to single library. 
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
    vlog_files = []
    for file_list in [target.files.to_list() for target in ctx.attr.vlog_files]:
        vlog_files += file_list 

    vhdl_files = []
    for file_list in [target.files.to_list() for target in ctx.attr.vhdl_files]:
        vhdl_files += file_list

    return BlockInfo(
        vlog_libs = _get_transitive_libs(vlog_files, ctx.attr.lib, [block[BlockInfo].vlog_libs for block in ctx.attr.blocks]),
        vhdl_libs = _get_transitive_libs(vhdl_files, ctx.attr.lib, [block[BlockInfo].vhdl_libs for block in ctx.attr.blocks]),
        sdc_files = depset(
            ctx.attr.sdc_files,
            transitive = [block[BlockInfo].sdc_files for block in ctx.attr.blocks],
            ),
    )

block = rule(
    doc = "Gathers HDL and .sdc files of a block ands it's dependencies.",
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

# Note that you must use actions.args for the arguments of the compiler 
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

    out_dir = paths.join(ctx.bin_dir.path, ctx.label.package)
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

        AN_DB_dir = ctx.actions.declare_directory("AN.DB")

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

    simv = ctx.actions.declare_file("simv")
    elab_args = ctx.actions.args()
    elab_args.add_all([
        "-full64",
        "-timescale=%s" % ctx.attr.timescale,
        "-CFLAGS",
        "-DVCS",
        "-debug_access+all",
        paths.join(local_paths.uvm_home, "dpi/uvm_dpi.cc"),
        "-j1", ctx.attr.top,
        "-o", paths.join(cd_path_fix, simv.path),
    ])

    command = "tree ;cd {out_dir}; {vcs} $@".format(
        vcs = paths.join(cd_path_fix, ctx.file._vcs.path),
        out_dir = out_dir,
    )

    daidir_path = ctx.actions.declare_directory("simv.daidir")

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

    run_simv = ctx.actions.declare_file("run_simv")
    ctx.actions.write(run_simv, content="""
    #!/bin/bash
    cd {package}
    simv -exitstatus $@
    """.format(package=ctx.label.package))

    return [DefaultInfo(
        executable=run_simv,
        runfiles=ctx.runfiles(files = [simv, daidir_path])
    )]
    

sim_test = rule(
    doc = "Verification test",
    implementation = _test_impl,
    attrs = test_attrs,
    test = True,
)

testbench = rule(
    doc = "Testbench",
    implementation = _test_impl,
    attrs = test_attrs,
)
