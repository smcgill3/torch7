## Makefile Method for making torch into a module for any lua
## Daniel D. Lee, Feb 2013.
## <ddlee@seas.upenn.edu>
## Stephen McGill, Apr 2014, 2017
## <smcgill3@seas.upenn.edu>
## sudo luarocks-5.1 install https://raw.githubusercontent.com/torch/cwrap/master/rocks/cwrap-scm-1.rockspec

.PHONY: all clean

#LUA?=$(shell which lua || which lua5.2 || which lua5.1 || which luajit)
LUA ?= $(shell pkg-config --list-all | egrep -o "^lua-?(jit|5\.?[123])" | sort | head -n1)
LUA_VERSION = $(shell $(LUA) -e 'print(_VERSION)' | cut -d' ' -f 2)
LUA_NAME = $(shell basename $(LUA))

PREFIX=/usr/local

# In case luarocks is not being used
CFLAGS?=-O3 -fPIC
INST_LIBDIR?=/usr/local/lib/lua/$(LUA_VERSION)
INST_LUADIR?=/usr/local/share/lua/$(LUA_VERSION)

ifndef OSTYPE
OSTYPE=$(shell uname -s | tr '[:upper:]' '[:lower:]')
endif

ifeq ($(OSTYPE),darwin) # OSX linking and installation
SHLIBEXT=dylib
else # Linux linking and installation
SHLIBEXT=so
endif

TH_SOURCES=$(shell find lib/TH -iname "*.c")
LUAT_SOURCES=$(shell find lib/luaT -iname "*.c")

TORCH_SOURCES=$(shell ls -1 *.c) \
	TensorMath.c \
	random.c

LUAT_OBJECTS=$(LUAT_SOURCES:.c=.o)
TH_OBJECTS=$(TH_SOURCES:.c=.o)
TORCH_OBJECTS=$(TORCH_SOURCES:.c=.o)

INCLUDES=-I. \
	-Ilib/luaT \
	-Ilib/TH

DEFINES=\
	-DUSE_SSE2 \
	-DUSE_SSE3 \
	-DHAVE_GCC_GET_CPUID \
	-DNDEBUG \
	-DTH_EXPORTS \
	-DTH_HAVE_THREAD \
	-DHAVE_MMAP=1 \
	-DHAVE_SHM_OPEN=1 \
	-DHAVE_SHM_UNLINK=1 \
	-DUSE_GCC_ATOMICS=1 \
	-D_FILE_OFFSET_BITS=64

CEXTRA=\
	-std=gnu99 \
	-fno-stack-protector \
	-fomit-frame-pointer \
	-ffast-math \
	-march=native \
	-mtune=native \
	-Werror=implicit-function-declaration \
	-Werror=format \
	-Wpedantic

ifeq ($(shell pkg-config --exists $(LUA_NAME) && echo 0),0)
LUA_INCDIR=$(shell pkg-config $(LUA_NAME) --cflags-only-I | sed -e s/^-I//)
else
LUA_INCDIR=-I/usr/include/lua \
	-I/usr/include/lua$(LUA_VERSION) \
	-I/usr/local/include/lua$(LUA_VERSION) \
	-I/usr/include/luajit-2.1 \
	-I/usr/local/include/luajit-2.1
endif

ifeq ($(OSTYPE),darwin)
MACOSX_DEPLOYMENT_TARGET?=10.8
CC=clang
LD=ld
SED=sed -i '' -e
LIBFLAG?=-bundle -undefined dynamic_lookup -all_load
DYLIBFLAG=-dylib -undefined dynamic_lookup -all_load
LDFLAGS=-framework Accelerate \
	-lm \
	-macosx_version_min $(MACOSX_DEPLOYMENT_TARGET)
CEXTRA+=-FAccelerate \
	-msse4.1 \
	-msse4.2 \
	-mavx \
	-mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET)
DEFINES+=\
	-DUSE_SSE4_1 \
	-DUSE_SSE4_2 \
	-DUSE_AVX
else
LIBFLAG?=-shared
LD=g++
# NOTE: This may need /usr/local/lib?
LDFLAGS=-fPIC -lm -lopenblas
#LDFLAGS=-fPIC -lm -lblas -llapack
SED=sed -i -e
endif

all: $(LUAT_SOURCES) $(TH_SOURCES) $(TORCH_SOURCES) libtorch libTH libluaT torch.lua

torch.lua:
	@echo "Forming torch.lua file"
	@printf "local libtorch = require'libtorch'\n" > $@
	@printf "torch.Tensor = torch.DoubleTensor\n\n" >> $@
	@cat Tensor.lua FFInterface.lua File.lua >> $@
	@printf "\nreturn torch\n" >> $@

TensorMath.c:
	$(LUA) TensorMath.lua $@

random.c:
	$(LUA) random.lua $@

lib/TH/THGeneral.h:
	cp lib/TH/THGeneral.h.in $@
	$(SED) 's/cmakedefine/define/g' $@
	$(SED) 's/@TH_INLINE@/inline/g' $@

lib/TH/*.c: lib/TH/THGeneral.h

.c.o:
	@echo Building $@
	$(CC) -c $(CFLAGS) $< -o $@ -I$(LUA_INCDIR) $(INCLUDES) $(DEFINES) $(CEXTRA)

libtorch: $(TORCH_OBJECTS) $(TH_OBJECTS) $(LUAT_OBJECTS)
	$(LD) $(LIBFLAG) $^ $(LDFLAGS) -o $@.so

libTH: $(TH_OBJECTS)
	$(LD) $(DYLIBFLAG) $^ $(LDFLAGS) -o $@.$(SHLIBEXT)

libluaT: $(LUAT_OBJECTS)
	$(LD) $(DYLIBFLAG) $^ $(LDFLAGS) -o $@.$(SHLIBEXT)

clean:
	rm -f $(TORCH_OBJECTS) $(TH_OBJECTS)
	rm -f *.so *.dylib
	rm -f TensorMath.c
	rm -f random.c
	rm -f lib/TH/THGeneral.h

install: libluaT libTH libtorch torch.lua
	mkdir -p $(INST_LIBDIR)
	cp libtorch.so $(INST_LIBDIR)
	mkdir -p $(INST_LUADIR)
	cp torch.lua $(INST_LUADIR)
	cp libTH.$(SHLIBEXT) $(PREFIX)/lib/
	cp libluaT.$(SHLIBEXT) $(PREFIX)/lib/
	# mkdir -p $(PREFIX)/include/torch/TH/generic/simd
	# cp lib/TH/generic/simd/*.h $(PREFIX)/include/torch/TH/generic/simd/

include:
	mkdir -p $(PREFIX)/include/torch/TH/generic
	cp lib/luaT/luaT.h $(PREFIX)/include/torch/
	cp lib/TH/*.h $(PREFIX)/include/torch/TH/
	cp lib/TH/generic/*.h $(PREFIX)/include/torch/TH/generic/

uninstall:
	rm -f $(INST_LIBDIR)/libtorch.so
	rm -f $(INST_LUADIR)/torch.lua
	rm -f $(INST_LIBDIR)/libTH.*
	rm -f $(INST_LIBDIR)/libluaT.*
	rm -rf $(PREFIX)/include/torch
