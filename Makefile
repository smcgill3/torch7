## Makefile Method for making torch into a module for any lua
## Daniel D. Lee, Feb 2013.
## <ddlee@seas.upenn.edu>
## Stephen McGill, Apr 2014
## <smcgill3@seas.upenn.edu>

TORCH_SOURCES=\
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
	lib/TH/THAllocator.c \
	lib/luaT/luaT.c \
  Generator.c \
	DiskFile.c \
	File.c \
	MemoryFile.c \
	PipeFile.c \
	Storage.c \
	Tensor.c \
	TensorMath.c \
	TensorOperator.c \
	Timer.c \
	init.c \
	random.c \
	utils.c

TORCH_OBJECTS=$(TORCH_SOURCES:.c=.o)

CFLAGS= \
	-std=c99 -pedantic \
	-c \
	-I/usr/local/include \
	-I/usr/include/lua \
	-I/usr/include/lua5.1 \
	-Ilib/luaT -Ilib/TH -I. \
	-O3 -fpic\
	-fno-stack-protector \
	-fomit-frame-pointer \
	-DTH_EXPORTS -DHAVE_MMAP=1 \
	-DUSE_SSE3 -DUSE_SSE2 -DNDEBUG \
	-DC_HAS_THREAD -DTH_HAVE_THREAD \
	-march=native -mtune=native
#-Wall -Wno-unused-function -Wno-unknown-pragmas

ifndef OSTYPE 
	OSTYPE = $(shell uname -s|awk '{print tolower($$0)}')
endif

ifeq ($(OSTYPE),darwin)
CC=clang
LD=ld -macosx_version_min 10.8
SED=sed -i '' -e
LDFLAGS=-undefined dynamic_lookup \
	-framework Accelerate \
	-lm \
	-L/usr/local/lib
CFLAGS+=-msse4.2 -DUSE_SSE4_2 \
	-msse4.1 -DUSE_SSE4_1 \
	-FAccelerate
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
	lua -e "package.path = package.path..';ext/?/init.lua;ext/?.lua'" TensorMath.lua TensorMath.c
	lua -e "package.path = package.path..';ext/?/init.lua;ext/?.lua'" random.lua random.c

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
	mkdir -p /usr/local/include/torch/TH/generic
	cp lib/luaT/luaT.h /usr/local/include/torch/
	cp lib/TH/*.h /usr/local/include/torch/TH/
	cp lib/TH/generic/* /usr/local/include/torch/TH/generic/
	mkdir -p /usr/local/lib/lua/5.1
	cp *.so /usr/local/lib/lua/5.1/
	cp *.dylib /usr/local/lib/

else
# Linux linking and installation

libtorch: $(TORCH_OBJECTS)
	$(LD) $^ $(LDFLAGS) -o $@.so

install: libtorch
	mkdir -p /usr/local/include/torch/TH/generic
	cp lib/luaT/luaT.h /usr/local/include/torch/
	cp lib/TH/*.h /usr/local/include/torch/TH/
	cp lib/TH/generic/* /usr/local/include/torch/TH/generic/
	mkdir -p /usr/local/lib/lua/5.1
	cp *.so /usr/local/lib/lua/5.1/
	cp *.so /usr/local/lib/
endif
