# Random seed flag
RandomSeedProvider = provider(fields = ["value"]) 

def _random_seed_impl(ctx):
    return RandomSeedProvider(value = ctx.build_setting_value)

random_seed = rule(
    doc = "Build setting for the `random_seed` flag.",
    implementation = _random_seed_impl,
    build_setting = config.bool(flag = True)
)

# Seed flag
SeedProvider = provider(fields = ["value"]) 

def _seed_impl(ctx):
    return SeedProvider(value = ctx.build_setting_value)

seed = rule(
    doc = "Build setting for the `seed` flag.",
    implementation = _seed_impl,
    build_setting = config.int(flag = True)
)