<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a name="#block"></a>

## block

<pre>
block(<a href="#block-name">name</a>, <a href="#block-blocks">blocks</a>, <a href="#block-lib">lib</a>, <a href="#block-sdc_files">sdc_files</a>, <a href="#block-vhdl_files">vhdl_files</a>, <a href="#block-vlog_files">vlog_files</a>)
</pre>

Gathers source files of a block ands it's dependencies.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| blocks |  List of blocks this block depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| lib |  Name of library of HDL files.   | String | optional | "work" |
| sdc_files |  List of sdc files which are to be applied for PNR.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| vhdl_files |  List fo .vhdl files.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| vlog_files |  List of .sv files   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a name="#sim_test"></a>

## sim_test

<pre>
sim_test(<a href="#sim_test-name">name</a>, <a href="#sim_test-blocks">blocks</a>, <a href="#sim_test-data">data</a>, <a href="#sim_test-defines">defines</a>, <a href="#sim_test-lib">lib</a>, <a href="#sim_test-timescale">timescale</a>, <a href="#sim_test-top">top</a>, <a href="#sim_test-vhdl_top">vhdl_top</a>, <a href="#sim_test-vlog_top">vlog_top</a>)
</pre>

Runs a test.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| blocks |  List of blocks this test depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| data |  Runtime dependencies of this test.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| defines |  Compiler defines. Formatted as string keyed dict of strings.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| lib |  Name of library of the top_file.   | String | optional | "work" |
| timescale |  Elaboration timescale flag   | String | optional | "1ns/1ns" |
| top |  Name of top level module.   | String | required |  |
| vhdl_top |  <code>.vhd</code> file which contains the top level module declared in <code>top</code>. <code>vlog_top</code> and <code>vhdl_top</code> are mutually exclusive.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| vlog_top |  <code>.v</code> / <code>.sv</code> file which contains the top level module declared in <code>top</code>. <code>vlog_top</code> and <code>vhdl_top</code> are mutually exclusive.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a name="#testbench"></a>

## testbench

<pre>
testbench(<a href="#testbench-name">name</a>, <a href="#testbench-blocks">blocks</a>, <a href="#testbench-data">data</a>, <a href="#testbench-defines">defines</a>, <a href="#testbench-lib">lib</a>, <a href="#testbench-timescale">timescale</a>, <a href="#testbench-top">top</a>, <a href="#testbench-vhdl_top">vhdl_top</a>, <a href="#testbench-vlog_top">vlog_top</a>)
</pre>

Testbench. Identical to `sim_test` but is not regarded as a test.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| blocks |  List of blocks this test depends on.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| data |  Runtime dependencies of this test.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| defines |  Compiler defines. Formatted as string keyed dict of strings.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | optional | {} |
| lib |  Name of library of the top_file.   | String | optional | "work" |
| timescale |  Elaboration timescale flag   | String | optional | "1ns/1ns" |
| top |  Name of top level module.   | String | required |  |
| vhdl_top |  <code>.vhd</code> file which contains the top level module declared in <code>top</code>. <code>vlog_top</code> and <code>vhdl_top</code> are mutually exclusive.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| vlog_top |  <code>.v</code> / <code>.sv</code> file which contains the top level module declared in <code>top</code>. <code>vlog_top</code> and <code>vhdl_top</code> are mutually exclusive.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |


<a name="#BlockInfo"></a>

## BlockInfo

<pre>
BlockInfo(<a href="#BlockInfo-vlog_libs">vlog_libs</a>, <a href="#BlockInfo-vhdl_libs">vhdl_libs</a>, <a href="#BlockInfo-sdc_files">sdc_files</a>)
</pre>

Provides structure of source files for compiling a dependency block

**FIELDS**


| Name  | Description |
| :-------------: | :-------------: |
| vlog_libs |  A dictionary of SystemVerilog / Verilog files.         The key of the dictionary is the name of a library,         and the value is a list of source files that belong         to that library.    |
| vhdl_libs |  A dictionary of VHDL files.The key         of the dictionary is the name of a library, and the         value is a list of source files that belong to that         library.    |
| sdc_files |  A list of sdc files which are to be         applied to a Quartus project which uses this block.    |


<a name="#regression_test"></a>

## regression_test

<pre>
regression_test(<a href="#regression_test-kwargs">kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :-------------: | :-------------: | :-------------: |
| kwargs |  <p align="center"> - </p>   |  none |


