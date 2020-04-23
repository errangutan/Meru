load("@bazel_json//lib:json_parser.bzl", "json_parse")
load("@vcs//:local_paths.bzl", "local_paths")
load("@bazel_skylib//lib:paths.bzl", "paths")

DAIDIR_FILES = [
    "simv.daidir/vcselab_misc_hsim_elab.db",
    "simv.daidir/build_db",
    "simv.daidir/elabmoddb.sdb",
    "simv.daidir/vcselab_misc_vpdnodenums",
    "simv.daidir/vcselab_master_hsim_virtintf_info.dat",
    "simv.daidir/mxmap.db",
    "simv.daidir/vcselab_misc_vcselabref.db",
    "simv.daidir/binmap.sdb",
    "simv.daidir/version.db",
    "simv.daidir/vcselab_misc_hsim_uds.db",
    "simv.daidir/vcselab_misc_mnmn.db",
    "simv.daidir/DPIFuncTaskList",
    "simv.daidir/nsparam.dat",
    "simv.daidir/mxopt.db",
    "simv.daidir/simv.kdb",
    "simv.daidir/unielab.vltop",
    "simv.daidir/vcselab_misc_partitionDbg.db",
    "simv.daidir/vcselab_misc_hsdef.db",
    "simv.daidir/pcc.sdb",
    "simv.daidir/constraint.sdb",
    "simv.daidir/vcselab_misc_midd.db",
    "simv.daidir/vcselab_master_hsim_elabout.db",
    "simv.daidir/external_functions",
    "simv.daidir/covg_defs",
    "simv.daidir/stitch_nsparam.dat",
    "simv.daidir/vcselab_misc_hsim_fegate.db",
    "simv.daidir/vloganopts.db",
    "simv.daidir/eblklvl.db",
    "simv.daidir/vcs_rebuild",
    "simv.daidir/.normal_done",
    "simv.daidir/vc_hdrs.o",
    "simv.daidir/hslevel_level.sdb",
    "simv.daidir/pcxpxmr.dat",
    "simv.daidir/prof.sdb",
    "simv.daidir/_748_archive_1.so",
    "simv.daidir/constraint_string_index",
    "simv.daidir/cc/cc_dummy_file",
    "simv.daidir/cc/cc_bcode.db",
    "simv.daidir/hslevel_rtime_level.sdb",
    "simv.daidir/vcselab_misc_partition.db",
    "simv.daidir/rmapats.so",
    "simv.daidir/scsim.db.dir/scsim.db.file",
    "simv.daidir/tt.sdb",
    "simv.daidir/cgname.json",
    "simv.daidir/hsscan_cfg.dat",
    "simv.daidir/mxsetup.db",
    "simv.daidir/hslevel_callgraph.sdb",
    "simv.daidir/.daidir_complete",
    "simv.daidir/saifNetInfo.db",
    "simv.daidir/vcselab_misc_hsim_lvl.db",
    "simv.daidir/debug_dump/topmodules",
    "simv.daidir/debug_dump/src_files_verilog",
    "simv.daidir/debug_dump/fsearch/idents_tapi.xml.gz",
    "simv.daidir/debug_dump/fsearch/fsearch.stat",
    "simv.daidir/debug_dump/fsearch/idents_rmKbIA.xml.gz",
    "simv.daidir/debug_dump/fsearch/check_fsearch_db",
    "simv.daidir/debug_dump/fsearch/.create_fsearch_db",
    "simv.daidir/debug_dump/HsimSigOptDb.sdb",
    "simv.daidir/debug_dump/.version",
    "simv.daidir/debug_dump/dve_debug.db.gz",
    "simv.daidir/debug_dump/AllModulesSkeletons.sdb",
    "simv.daidir/debug_dump/dumpcheck.db",
    "simv.daidir/debug_dump/vir.sdb",
    "simv.daidir/vcselab_misc_hsim_name.db",
    "simv.daidir/crc.db",
    "simv.daidir/rmapats.dat",
    "simv.daidir/vc_hdrs.c",
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

    vlog_files = [f.files for f in vlog_files]
    vhdl_files = [f.files for f in vhdl_files]

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
        "_vlogan" : attr.label(
            default = "@vcs//:vlogan"
        ),
        "_vcs" : attr.label(
            default = "@vcs//:vcs"
        ),
        "_vlogan_runfiles" : attr.label(
            default = "@vcs//:vlogan_runfiles"
        ),
        "_uvm_pkg" : attr.label(
            default = "@vcs//:uvm_pkg"
        )
    }

def _link_outputs(ctx, outputs, command):
    link_dict = {output:"{}/{}/{}".format(ctx.bin_dir.path,ctx.label.package,output) for output in outputs}
    bash_links = ' '.join(["[{}]={}".format(k,v) for k,v in link_dict.items()])
    command = """
    {command} && {{
        declare -A LINKS=({bash_links})
        for l in "${{!LINKS[@]}}"
        do
            rm -r ${{LINKS[$l]}}
            echo $(realpath $l) ${{LINKS[$l]}}
            ln -snf $(realpath $l) ${{LINKS[$l]}} 
        done\n
    }}
    """.format(
        command=command,
        bash_links=bash_links
    )

    return command

def _get_file_obj(filegroup_target):
    return filegroup_target.files.to_list()[0]

# Note that you must use actions.args for the arguments of the compiler 
def _test_impl(ctx): 
    
    # If VCS environment variables not set, fail.
    # if local_paths.vcs_home == None:
        # fail(msg = "VCS_HOME environment variable not set. Add \"bazel build --action_env VCS_HOME=<path> to /etc/bazel.bazelrc\"")
    # if local_paths.vcs_license == None:
        # fail(msg = "VCS_LICENSE environment variable not set. Add \"bazel build --action_env VCS_LICENSE=<path> to /etc/bazel.bazelrc\"")

    vlogan = _get_file_obj(ctx.attr._vlogan)
    uvm_pkg = _get_file_obj(ctx.attr._uvm_pkg)

    defines = json_parse(ctx.attr.defines)
    libs = _get_transitive_libs([], [], ctx.attr.lib, ctx.attr.blocks) # Merge libs of dependencies into single dict

    for lib_key in libs:

        args = ctx.actions.args()
        vlog_files = [item.to_list()[0] for item in libs[lib_key].vlog_files.to_list()]
        args.add("-full64")
        args.add_all(["-work","WORK"])
        args.add("+incdir+{}".format(local_paths.vcs_home + "etc/uvm"))
        args.add(uvm_pkg)
        args.add_all(["-ntb_opts","uvm"])
        args.add("-sverilog")
        args.add_all(vlog_files)

        AN_DB_tar = ctx.actions.declare_file("AN.DB.tar")
        print(AN_DB_tar.path)
        ctx.actions.run_shell(
            inputs = depset([uvm_pkg] + vlog_files, transitive=[ctx.attr._vlogan_runfiles.files, ctx.attr._vlogan.files]),
            outputs = [AN_DB_tar],
            command = "{vlogan} $@; tar -cvf {andb} AN.DB".format(
                vlogan = vlogan.path,
                andb = paths.join(ctx.bin_dir.path, ctx.label.package, "AN.DB.tar")
            ),
            arguments = [args],
            env = {
                "VCS_HOME" : local_paths.vcs_home,
                "HOME" : "/dev/null",
		"UVM_HOME" : "/usr/synopsys/vcs-mx/O-2018.09-SP2/etc/uvm"
            },
            mnemonic = "Vlogan",
            progress_message = "Analysing verilog files.",
        )
        
    
    simv = ctx.actions.declare_file("simv")
    elab_args = ctx.actions.args()
    elab_args.add("-full64")
    elab_args.add("-timescale=1ns/1ns")
    elab_args.add("-CFLAGS")
    elab_args.add("-DVCS")
    elab_args.add("-debug_access+all")
    elab_args.add("/usr/synopsys/vcs-mx/O-2018.09-SP2/etc/uvm/dpi/uvm_dpi.cc")
    elab_args.add_all(["-j1", ctx.attr.top])
    elab_args.add_all(["-o", simv])

    vcs = _get_file_obj(ctx.attr._vcs)
    command = "tar -xf {andb}; {vcs} -full64 -timescale=1ns/1ns -CFLAGS -DVCS -debug_access+all /usr/synopsys/vcs-mx/O-2018.09-SP2/etc/uvm/dpi/uvm_dpi.cc -j1 top_tb -o {simv}".format(
        andb = AN_DB_tar.path,
        vcs = vcs.path,
	    simv = simv.path,
    )

    daidir_path = ctx.actions.declare_directory("simv.daidir")

    ctx.actions.run_shell(
        outputs = [simv, daidir_path],
        inputs = depset([AN_DB_tar], transitive=[ctx.attr._vcs.files]),
        command = command,
        arguments = [],
        env = {
            "VCS_HOME" : local_paths.vcs_home,
            "LM_LICENSE_FILE" : local_paths.lm_license_file,
	        "UVM_HOME" : "/usr/synopsys/vcs-mx/O-2018.09-SP2/etc/uvm",
            "SNPSLMD_LICENSE_FILE" : "27020@10.0.1.4",
            "HOME" : "/dev/null",
            "PATH" : "/usr/bin:/bin",
        },
    )

    run_simv = ctx.actions.declare_file("run_simv")
    ctx.actions.write(run_simv, content="""
    #!/bin/bash
    cd {package}
    simv $@
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
