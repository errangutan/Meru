load("@bazel_json//lib:json_parser.bzl", "json_parse")
load("@vcs//:local_paths.bzl", "local_paths")
load("@bazel_skylib//lib:paths.bzl", "paths")

BlockInfo = provider(
    doc = "Provides sdc_files, and a libs dict. Each lib is a struct with a vlog_files depset and a vhdl_files depset.",
    fields = ["libs", "sdc_files"]
)

RegsInfo = provider(
    doc = "Provides info about the findl"
)

def _get_transitive_libs(vlog_files, vhdl_files, files_lib, blocks):
    lib_dict_list = [block[BlockInfo].libs for block in blocks]

    # Get all lib names in side lib dicts
    libs = [files_lib]
    for lib_dict in lib_dict_list:
        libs.extend(lib_dict.keys())
    libs = [x for i,x in enumerate(libs) if x not in libs[:i]] # Remove doubles

    # For every library we found in the libs dicts, get all depsets of that library
    output_libs_dict = {}
    for lib in libs:
        output_libs_dict[lib] = struct(
            vlog_files = depset(
                vlog_files if lib == files_lib else [],
                transitive=[lib_dict[lib].vlog_files for lib_dict in lib_dict_list if lib in lib_dict]
            ),
            vhdl_files = depset(
                vhdl_files if lib == files_lib else [],
                transitive=[lib_dict[lib].vhdl_files for lib_dict in lib_dict_list if lib in lib_dict]
            ),
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
        libs = _get_transitive_libs(vlog_files, vhdl_files, ctx.attr.lib, ctx.attr.blocks),
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
        "top_file" : attr.label(
            doc = "HDL File which contains the top level module.",
            allow_files = [".vhdl", ".sv", ".v"],
            mandatory = True,
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
        "defines" : attr.string(
            doc = "Compiler defines. Formatted as string keyed dict of strings.",
            default = "{}",
        ),
        "timescale" : attr.string(
            doc = "Elaboration timescale flag",
            default = "1ns/1ns",
        ),
        "_vlogan" : attr.label(
            default = "@vcs//:vcs/bin/vlogan",
            allow_single_file = True
        ),
        "_vlogan_runfiles" : attr.label(
            default = "@vcs//:vlogan_runfiles",
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
        )
    }

# Note that you must use actions.args for the arguments of the compiler 
def _test_impl(ctx): 

    defines = json_parse(ctx.attr.defines)
    libs = _get_transitive_libs([], [], ctx.attr.lib, ctx.attr.blocks) # Merge libs of dependencies into single dict

    out_dir = paths.join(ctx.bin_dir.path, ctx.label.package)
    cd_path_fix = "/".join(len(out_dir.split("/"))*[".."])
    print (cd_path_fix)

    for lib_key, lib in libs.items():

        args = ctx.actions.args()
        args.add_all([
            "-full64",
            "-work","WORK",
            "+incdir+%s" % paths.join(cd_path_fix, ctx.file._uvm.path),
            paths.join(cd_path_fix, ctx.file._uvm.path, "uvm_pkg.sv"),
            "-ntb_opts","uvm",
            "-sverilog",
        ])

        files_args = ctx.actions.args()
        files_args.add_all(lib.vlog_files, format_each="{}/%s".format(cd_path_fix))

        AN_DB_dir = ctx.actions.declare_directory("AN.DB")

        ctx.actions.run_shell(
            inputs = depset(
                [ctx.file._uvm_pkg, ctx.file._vlogan],
                transitive=[lib.vlog_files, ctx.attr._vlogan_runfiles.files]),
            outputs = [AN_DB_dir],
            command = "cd {out_dir};{vlogan} $@".format(
                vlogan = paths.join(cd_path_fix, ctx.file._vlogan.path),
                out_dir = out_dir,
            ),
            arguments = [args, files_args],
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
        "-timescale=1ns/1ns",
        "-CFLAGS",
        "-DVCS",
        "-debug_access+all",
        "/usr/synopsys/vcs-mx/O-2018.09-SP2/etc/uvm/dpi/uvm_dpi.cc",
        "-j1", ctx.attr.top,
        "-o", simv,
    ])

    command = "cd {out_dir}; {vcs} -full64 -timescale=1ns/1ns -CFLAGS -DVCS -debug_access+all /usr/synopsys/vcs-mx/O-2018.09-SP2/etc/uvm/dpi/uvm_dpi.cc -j1 top_tb -o {simv}".format(
        vcs = paths.join(cd_path_fix, ctx.file._vcs.path),
	    simv = paths.join(cd_path_fix, simv.path),
        out_dir = out_dir,
    )

    daidir_path = ctx.actions.declare_directory("simv.daidir")
    print(ctx.var)

    ctx.actions.run_shell(
        outputs = [simv, daidir_path],
        inputs = [AN_DB_dir, ctx.file._vcs],
        command = command,
        arguments = [],
        env = {
            "VCS_HOME" : local_paths.vcs_home,
            "LM_LICENSE_FILE" : local_paths.lm_license_file,
            "SNPSLMD_LICENSE_FILE" : "27020@10.0.1.4",
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
