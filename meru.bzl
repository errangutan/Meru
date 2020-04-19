load("@bazel_json//lib:json_parser.bzl", "json_parse")
load("@local_paths//:local_paths.bzl", "local_paths")
load("@bazel_skylib//lib:paths.bzl", "paths")

_VLOGAN_OUTPUT = [
    "AllModulesSkeletons.sdb",
    "debug_dump",
    "dve.sdb",
    "modfilename.db",
    "str.index.db",
    "vir.sdb",
    "vloganopts.db",
    "compat.db",
    "dumpcheck.db",
    "make.vlogan",
    "str.db",
    "str.info.db",
    "vir_global.sdb",
]

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
    return BlockInfo(
        libs = _get_transitive_libs(ctx.attr.vlog_files, ctx.attr.vhdl_files, ctx.attr.lib, ctx.attr.blocks),
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
    }

# Note that you must use actions.args for the arguments of the compiler 
def _test_impl(ctx): 
    
    # If VCS environment variables not set, fail.
    if local_paths.vcs_home == None:
        fail(msg = "VCS_HOME environment variable not set. Add \"bazel build --action_env VCS_HOME=<path> to /etc/bazel.bazelrc\"")
    if local_paths.vcs_license == None:
        fail(msg = "VCS_LICENSE environment variable not set. Add \"bazel build --action_env VCS_LICENSE=<path> to /etc/bazel.bazelrc\"")

    vlogan = paths.join(local_paths.vcs_home, "bin/vlogan")

    defines = json_parse(ctx.attr.defines)
    libs = _get_transitive_libs([], [], ctx.attr.lib, ctx.attr.blocks) # Merge libs of dependencies into single dict
    
    for lib_key in libs:
        args = ctx.actions.args()
        vlog_files = libs[lib_key].vlog_files
        args.add("-full64")
        args.add("-work {}".format(lib_key))
        args.add("+incdir+{}".format(paths.join(local_paths.vcs_home), "etc/uvm/src"))
        args.add(paths.join(local_paths.vcs_home, "etc/uvm/uvm_pkg.sv"))
        args.add("-ntb_opts uvm")
        args.add("-sverilog")
        args.add_all(vlog_files)

        output_files = [ctx.actions.declare_file(out_file_path) for out_file_path in _VLOGAN_OUTPUT]
        ctx.actions.run(
            outputs = output_files,
            executable = vlogan,
            arguments = [args],
            env = {"VCS_HOME" : local_paths.vcs_home},
            mnemonic = "Vlogan",
            progress_message = "Analysing verilog files.",
        )
        
        shit = ctx.actions.declare_file("shit")
        ctx.actions.write(shit, content="")
        return [DefaultInfo(executable=shit, files=depset(output_files))]


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