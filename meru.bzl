load("@bazel_json//lib:json_parser.bzl", "json_parse")

BlockInfo = provider(
    doc = "Provides sdc_files, and a libs dict. Each lib is a struct with a vlog_files depset and a vhdl_files depset.",
    fields = ["libs", "sdc_files"]
)

def _merge_lib(lib1, lib2):
    return struct(
        vlog_files = depset(transitive = [lib1.vlog_files, lib2.vlog_files]),
        vhdl_files = depset(transitive = [lib1.vhdl_files, lib2.vhdl_files]),
    )

def _get_transitive_libs(vlog_files, vhdl_files, blocks):
    lib_dict_list = [block[BlockInfo].libs for block in blocks]

    # Get all lib names in side lib dicts
    libs = []
    for lib_dict in lib_dict_list:
        libs.extend(lib_dict.keys())
    libs = [x for i,x in enumerate(libs) if x not in libs[:i]] # Remove doubles

    # For every library we found in the libs dicts, get all depsets of that library
    output_libs_dict = {}
    for lib in libs:
        output_libs_dict[lib] = struct(
            vlog_files = depset(vlog_files, transitive=[lib_dict[lib].vlog_files for lib_dict in lib_dict_list if lib in lib_dict]),
            vhdl_files = depset(vhdl_files, transitive=[lib_dict[lib].vhdl_files for lib_dict in lib_dict_list if lib in lib_dict]),
        )
    
    return output_libs_dict

def _block_impl(ctx):
    return BlockInfo(
        libs = _get_transitive_libs(ctx.attr.vlog_files, ctx.attr.vhdl_files, ctx.attr.blocks),
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
        )
    },
    provides = [BlockInfo]
)

test_attrs = {
        "top" : attr.string(
            doc = "Name of top level module.",
            #mandatory = True,
        ),
        "top_file" : attr.label(
            doc = "HDL File which contains the top level module.",
            allow_files = [".vhdl", ".sv", ".v"],
            #mandatory = True,
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

def _test_impl(ctx):
    defines = json_parse(ctx.attr.defines)

sim_test = rule(
    implementation = _test_impl,
    attrs = test_attrs,
    test = True,
)

testbench = rule(
    implementation = _test_impl,
    attrs = test_attrs,
    test = False
)