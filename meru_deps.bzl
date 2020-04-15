load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def meru_deps():
    """Loads common dependencies needed to use meru"""

    if not native.existing_rule("bazel_json"):
        http_archive(
            name = "bazel_json",
            urls = ["https://github.com/erickj/bazel_json/archive/e954ef2c28cd92d97304810e8999e1141e2b5cc8.zip"],
            strip_prefix = "bazel_json-e954ef2c28cd92d97304810e8999e1141e2b5cc8",
            sha256 = "4860e929115395403f7b33fc32c2a034d4b7990364b65c22244cb58cadd3a4a5",
        )