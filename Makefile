## Makefile Method for making torch into a module for any lua
## Daniel D. Lee, Feb 2013.
## <ddlee@seas.upenn.edu>
## Stephen McGill, Apr 2014
## <smcgill3@seas.upenn.edu>

#LUA=lua
LUA=luajit

TORCH_SOURCES=\
	lib/TH/THAllocator.c \
	lib/TH/THAtomic.c \
	lib/TH/THBlas.c \
	lib/TH/THDiskFile.c \
	lib/TH/THFile.c \
	lib/TH/THGeneral.c \
	lib/TH/THLapack.c \
	lib/TH/THLogAdd.c \
	lib/TH/THMemoryFile.c \
	lib/TH/THRandom.c \
	lib/TH/THStorage.c \
	lib/TH/THTensor.c \
	lib/TH/THVector.c \
	lib/TH/generic/THBlas.c \
	lib/TH/generic/THLapack.c \
	lib/TH/generic/THStorage.c \
	lib/TH/generic/THStorageCopy.c \
	lib/TH/generic/THTensor.c \
	lib/TH/generic/THTensorConv.c \
	lib/TH/generic/THTensorCopy.c \
	lib/TH/generic/THTensorLapack.c \
	lib/TH/generic/THTensorMath.c \
	lib/TH/generic/THTensorRandom.c \
	lib/TH/generic/THVectorDefault.c \
	lib/TH/generic/THVectorDispatch.c \
	lib/TH/generic/simd/convolve.c \
	lib/TH/generic/simd/convolve5x5_sse.c \
	lib/TH/generic/simd/convolve5x5_avx.c \
	lib/luaT/luaT.c \
	DiskFile.c \
	File.c \
	Generator.c \
	MemoryFile.c \
	PipeFile.c \
	Storage.c \
	Tensor.c \
	TensorOperator.c \
	Timer.c \
	init.c \
	utils.c \
	TensorMath.c \
	random.c

TORCH_OBJECTS=$(TORCH_SOURCES:.c=.o)

CFLAGS= \
	-c \
	-I/usr/local/include \
	-Ilib/luaT -Ilib/TH -I. \
	-O3 -fpic\
	-fno-stack-protector \
	-fomit-frame-pointer \
	-DTH_EXPORTS -DHAVE_MMAP=1 \
	-DUSE_SSE3 -DUSE_SSE2 \
	-DNDEBUG \
	-DTH_HAVE_THREAD \
	-DUSE_GCC_ATOMICS=1 \
	-march=native -mtune=native \
	-ffast-math \
	-Werror=implicit-function-declaration -Werror=format -Wpedantic

LUA_VERSION=5.1
LUAJIT_VERSION=2.1

ifeq ($(shell pkg-config --exists luajit && echo 0),0)
LUA_INC=$(shell pkg-config luajit --cflags-only-I)
else ifeq ($(shell pkg-config --exists lua$(LUA_VERSION) && echo 0),0)
LUA_INC=$(shell pkg-config lua$(LUA_VERSION) --cflags-only-I)
else
LUA_INC = -I/usr/include/lua \
	-I/usr/include/lua5.1 \
	-I/usr/local/include/lua5.1 \
	-I/usr/local/include/luajit-2.1
endif
CFLAGS+=$(LUA_INC)

ifndef OSTYPE
	OSTYPE = $(shell uname -s|awk '{print tolower($$0)}')
endif

ifeq ($(OSTYPE),darwin)
CC=clang
LD=ld
SED=sed -i '' -e
LDFLAGS= \
	-undefined dynamic_lookup \
	-macosx_version_min 10.10 \
	-framework Accelerate \
	-lm \
	-L/usr/local/lib
CFLAGS+= \
	-mavx -DUSE_AVX \
	-msse4.2 -DUSE_SSE4_2 \
	-msse4.1 -DUSE_SSE4_1 \
	-FAccelerate \
	-mmacosx-version-min=10.11
else
LD=g++
#LDFLAGS=-shared -fpic -lm -lblas -llapack
LDFLAGS=-shared -fpic -lm -lopenblas
SED=sed -i -e
endif

all: $(TORCH_SOURCES) libtorch

prep:
	cp lib/TH/THGeneral.h.in lib/TH/THGeneral.h
	$(SED) 's/cmakedefine/define/g' lib/TH/THGeneral.h
	$(SED) 's/@TH_INLINE@/inline/g' lib/TH/THGeneral.h
	$(LUA) TensorMath.lua TensorMath.c
	$(LUA) random.lua random.c

.c.o:
	cc $(CFLAGS) $< -o $@

clean:
	rm -f $(TORCH_OBJECTS)
	rm -f *.so *.dylib
	rm -f TensorMath.c
	rm -f random.c
	rm -f lib/TH/THGeneral.h

ifeq ($(OSTYPE),darwin)
# OSX linking and installation
# Mach-O means BUNDLE for lua loading, DYLIB for linking (2 diff files...)
# GCC is -dynamiclib, clang is -dylib for the DYLIB
# lua loads .so files, dylib files are linked

libtorch: $(TORCH_OBJECTS)
	$(LD) -bundle $^ $(LDFLAGS) -o $@.so
	$(LD) -dylib $^ $(LDFLAGS) -o $@.dylib

install: libtorch
	mkdir -p /usr/local/lib/lua/5.1
	cp *.so /usr/local/lib/lua/5.1/
	cp *.dylib /usr/local/lib/
	mkdir -p /usr/local/include/torch/TH/generic
	cp lib/luaT/luaT.h /usr/local/include/torch/
	cp lib/TH/*.h /usr/local/include/torch/TH/
	cp lib/TH/generic/*.h /usr/local/include/torch/TH/generic/
	mkdir -p /usr/local/include/torch/TH/generic/simd
	cp lib/TH/generic/simd/*.h /usr/local/include/torch/TH/generic/simd/
#	cp lib/TH/generic/THVector.c /usr/local/include/torch/TH/generic
else
# Linux linking and installation

libtorch: $(TORCH_OBJECTS)
	$(LD) $^ $(LDFLAGS) -o $@.so

install: libtorch
	mkdir -p /usr/local/lib/lua/5.1
	cp *.so /usr/local/lib/lua/5.1/
	cp *.so /usr/local/lib/
	mkdir -p /usr/local/include/torch/TH/generic
	cp lib/luaT/luaT.h /usr/local/include/torch/
	cp lib/TH/*.h /usr/local/include/torch/TH/
	mkdir -p /usr/local/include/torch/TH/generic/simd/
	cp lib/TH/generic/simd/*.h /usr/local/include/torch/TH/generic/simd/
#	cp lib/TH/generic/THVector.c /usr/local/include/torch/TH/generic
endif
