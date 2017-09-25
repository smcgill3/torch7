package = "torch"
version = "7.0-0"
source = {
  url = "git://github.com/smcgill3/torch7.git"
}
description = {
  summary = "Install torch7 via standard luarocks",
  detailed = [[
      Install torch7 via standard luarocks
    ]],
  homepage = "https://github.com/smcgill3/torch7",
  maintainer = "Stephen McGill <stephen.g.mcgill@gmail.com>",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1",
  --"cwrap" https://raw.githubusercontent.com/torch/cwrap/master/rocks/cwrap-scm-1.rockspec
}
build = {
  type = "make",
  build_variables = {
    CFLAGS="$(CFLAGS)",
    LIBFLAG="$(LIBFLAG)",
    LUA_LIBDIR="$(LUA_LIBDIR)",
    LUA_BINDIR="$(LUA_BINDIR)",
    LUA_INCDIR="$(LUA_INCDIR)",
    LUA="$(LUA)",
  },
  install_variables = {
    INST_PREFIX="$(PREFIX)",
    INST_BINDIR="$(BINDIR)",
    INST_LIBDIR="$(LIBDIR)",
    INST_LUADIR="$(LUADIR)",
    INST_CONFDIR="$(CONFDIR)",
  },
}
