RandomSeedProvider = provider(fields = ["value"]) 

def _random_seed_impl(ctx):
    return RandomSeedProvider(value = ctx.build_setting_value)

random_seed = rule(
    doc = "Build setting for the random seed flag",
    implementation = _random_seed_impl,
    build_setting = config.bool(flag = True)
)