final: prev: {
  bulk_extractor = prev.bulk_extractor.overrideAttrs (old: {
    # Expat 2.9 deprecates XML_GetCurrentLineNumber; upstream enables -Werror.
    env =
      (old.env or {})
      // {
        NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=deprecated-declarations";
      };
  });
}
