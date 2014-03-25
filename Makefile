## Makefile Method for making torch into a module for any lua
## Daniel D. Lee, Feb 2013.
## <ddlee@seas.upenn.edu>
## Stephen McGill, Feb 2013
## <smcgill3@seas.upenn.edu>

CC=gcc
CXX=g++
LD=g++
# GCC is dynamiclib, clang is dylib
DYNAMICFLAG=-dynamiclib
#DYNAMICFLAG=-dylib
BUNDLEFLAG=

ifndef OSTYPE 
	OSTYPE = $(shell uname -s|awk '{print tolower($$0)}')
endif

CPPFLAGS= \
	-std=c99 -pedantic \
	-c \
	-I/usr/local/include \
	-I/usr/include/lua5.1 \
	-Ilib/luaT -Ilib/TH -I. \
	-O3 -fpic\
	-fno-stack-protector \
	-fomit-frame-pointer \
	-DTH_EXPORTS -DHAVE_MMAP=1 \
	-DUSE_SSE3 -DUSE_SSE2 -DNDEBUG \
	-DC_HAS_THREAD -DTH_HAVE_THREAD
#-Wall -Wno-unused-function -Wno-unknown-pragmas

LDFLAGS= \
	-shared -fpic -lm -lblas -llapack
#	-fomit-frame-pointer
SED=-i -e

ifeq ($(OSTYPE),darwin)
SED=-i '' -e
LDFLAGS=-undefined dynamic_lookup \
	-framework Accelerate \
	-lm \
	-L/usr/local/lib \
#	-macosx_version_min 10.6

BUNDLEFLAG=-bundle

CPPFLAGS+=-msse4.2 -DUSE_SSE4_2 \
	-msse4.1 -DUSE_SSE4_1 \
	-FAccelerate

else
CPPFLAGS+=-march=native -mtune=native 
endif

TORCH_SOURCES= \
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
TORCH_LIBRARY=torch.so

all: $(TORCH_SOURCES) $(TORCH_LIBRARY)

prep:
	cp lib/TH/THGeneral.h.in lib/TH/THGeneral.h
	sed $(SED) 's/cmakedefine/define/g' lib/TH/THGeneral.h
	sed $(SED) 's/@TH_INLINE@/inline/g' lib/TH/THGeneral.h
	sed $(SED) 's/luaopen_libtorch/luaopen_torch/g' init.c
	lua -e "package.path = package.path..';ext/?/init.lua;ext/?.lua'" TensorMath.lua TensorMath.c
	lua -e "package.path = package.path..';ext/?/init.lua;ext/?.lua'" random.lua random.c

$(TORCH_LIBRARY): $(TORCH_OBJECTS) 
	$(LD) $(BUNDLEFLAG)  $^ $(LDFLAGS) -o $@
	$(LD) $(DYNAMICFLAG) $^ $(LDFLAGS) -o lib$@

.c.o:
	$(CC) $(CPPFLAGS) $< -o $@

install: $(TORCH_LIBRARY)
	cp lib*.so /usr/local/lib
	mkdir -p /usr/local/include/torch/TH/generic
	cp lib/luaT/luaT.h /usr/local/include/torch/
	cp lib/TH/*.h /usr/local/include/torch/TH/
	cp lib/TH/generic/* /usr/local/include/torch/TH/generic/
	mkdir -p /usr/local/lib/lua/5.1
	cp torch.so /usr/local/lib/lua/5.1/

clean:
	rm -f $(TORCH_LIBRARY) *.so
	rm -f $(TORCH_OBJECTS)
	rm -f TensorMath.c
	rm -f random.c
	rm -f lib/TH/THGeneral.h
	sed $(SED) 's/luaopen_torch/luaopen_libtorch/g' init.c
