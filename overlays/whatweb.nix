final: prev: {
  # Upstream passes ruby_3_4 to bundlerEnv, which expects the argument named ruby.
  whatweb = prev.whatweb.override {
    bundlerEnv = args: prev.bundlerEnv (args // {ruby = prev.ruby_3_4;});
  };
}
