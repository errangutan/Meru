Data = provider(fields = {"data" : "String keyed dictionary of strings"})

def _data_provider_impl(ctx):
    return Data(data = struct(**ctx.attr.data))

data_provider = rule(
    doc = """Used to provide a constant dict to whoever
    depends on the target. This is useful for repositories which are
    created by repository rules and want to provide a information
    about the repository.""",
    implementation = _data_provider_impl,
    attrs = {"data" : attr.string_dict(doc="Information to be provided.")},
    provides = [Data],
)