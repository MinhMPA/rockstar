# Makefile for building the ROCKSTAR halo finder
#
# This updated Makefile adds support for linking against the
# libtirpc library, which provides the XDR/SunRPC routines
# required by the tipsy I/O code.  It also moves all library
# references to the end of the link commands to ensure that
# undefined symbols are resolved correctly.  Finally, it
# defines _DEFAULT_SOURCE to silence deprecation warnings
# from glibc.

##############################
# Compiler and flags
##############################

# Allow the user to override CC on the command line.  The default
# compiler is the system C compiler.
CC      ?= cc

# Base CFLAGS.  You can add your own flags when invoking make, for example
# `make CFLAGS="-O2 -march=native"`.
CFLAGS  ?= -Wall -fno-math-errno -fPIC -m64 -O3 -std=c99 -g

# Linker flags may include rpath options or other linker-specific flags.
LDFLAGS ?=

# Extra flags used by some targets.  Users can override this when needed.
EXTRA_FLAGS ?=

# Flags passed when building shared objects.  Typically contains
# `-shared -Wl,-soname,librockstar.so` on ELF systems.  Adjust as needed.
OFLAGS  ?= -shared

##############################
# TIRPC/XDR detection
##############################

# The tipsy reader uses the XDR/SunRPC API.  On modern Linux systems
# these symbols live in the libtirpc library.  Use pkg-config to
# query the appropriate include and linker flags.  If pkg-config is
# unavailable, you can instead uncomment the fallback definitions
# below.

PKG_TIRPC_CFLAGS := $(shell pkg-config --cflags libtirpc 2>/dev/null)
PKG_TIRPC_LIBS   := $(shell pkg-config --libs   libtirpc 2>/dev/null)

# Append the detected flags to CFLAGS and LIBS.  Define
# _DEFAULT_SOURCE to silence deprecation warnings for _BSD_SOURCE
# and _SVID_SOURCE.  If your distribution installs the tirpc
# headers under /usr/include/tirpc and you need to set the include
# path manually, uncomment the fallback section below and add
# `-DHAVE_TIRPC` to enable the conditional includes in the source.
CFLAGS += -D_DEFAULT_SOURCE $(PKG_TIRPC_CFLAGS)
LIBS   += $(PKG_TIRPC_LIBS)

# The math library is required for functions like pow(), cbrt(), log(),
# exp(), etc.  Linking against libm (-lm) resolves these symbols.
LIBS   += -lm

# Fallback definitions for systems without pkg-config support.
# Uncomment the following lines if pkg-config is not available
# or does not know about libtirpc on your system.  The -DHAVE_TIRPC
# define allows the source to include <tirpc/rpc/xdr.h> instead of
# <rpc/xdr.h>.
# CFLAGS += -I/usr/include/tirpc -DHAVE_TIRPC
# LIBS   += -ltirpc

##############################
# Source files
##############################

# List of C files used by multiple targets.  If you add or remove
# source files, update this variable accordingly.  The ordering of
# object files at link time matters because libraries must follow
# objects that reference them.
CFILES = rockstar.c check_syscalls.c fof.c groupies.c \
	subhalo_metric.c potential.c nfw.c jacobi.c fun_times.c \
	interleaving.c universe_time.c hubble.c integrate.c distance.c \
	config_vars.c config.c bounds.c inthash.c io/read_config.c \
	client.c server.c merger.c inet/socket.c inet/rsocket.c inet/address.c \
	io/meta_io.c io/io_internal.c io/io_ascii.c io/stringparse.c \
	io/io_gadget.c io/io_generic.c io/io_art.c io/io_tipsy.c \
	io/io_bgc2.c io/io_util.c

##############################
# Build rules
##############################

.PHONY: all reg lib bgc2 parents substats clean dist versiondist

# Default target builds the main executable
all: reg

# Build a distribution tarball based on the version defined in
# Rockstar/version.h.  The version string is extracted with perl
# and used to rename the unpacked directory before re-tarring.
versiondist:
	$(MAKE) dist DIST_FLAGS="$(DIST_FLAGS)"
	rm -rf dist
	mkdir dist
	cd dist; \
	  tar xzf ../rockstar.tar.gz; \
	  perl -ne '/\#define.*VERSION\D*([\d\.rcRC-]+)/ && print $$1' Rockstar/version.h > NUMBER; \
	  mv Rockstar Rockstar-`cat NUMBER`; \
	  tar czf rockstar-`cat NUMBER`.tar.gz Rockstar-`cat NUMBER`

# Build the main ROCKSTAR executable.  Place libraries last in the
# command so that the linker can resolve undefined symbols in the
# preceding object files.  EXTRA_FLAGS can contain additional
# libraries or linker options supplied by the user.
reg:
	$(CC) $(CFLAGS) main.c $(CFILES) -o rockstar $(LDFLAGS) $(EXTRA_FLAGS) $(LIBS)

# Build the shared library version of ROCKSTAR.  The OFLAGS variable
# should contain flags appropriate for creating a shared object (e.g.
# -shared -Wl,-soname,librockstar.so).  LDFLAGS and LIBS are placed
# after the objects to satisfy linker ordering requirements.
lib:
	$(CC) $(CFLAGS) $(CFILES) -o librockstar.so $(LDFLAGS) $(OFLAGS) $(LIBS)

# Build utility programs for BGC2 file processing.  Each command
# compiles the necessary source files, links with OFLAGS, LDFLAGS,
# and any extra libraries at the end.
bgc2:
	$(CC) $(CFLAGS) io/extra_bgc2.c util/redo_bgc2.c $(CFILES) -o util/finish_bgc2 $(LDFLAGS) $(OFLAGS) $(LIBS)
	$(CC) $(CFLAGS) io/extra_bgc2.c util/bgc2_to_ascii.c $(CFILES) -o util/bgc2_to_ascii $(LDFLAGS) $(OFLAGS) $(LIBS)

# Build the parent-finding utility.  Since it only depends on
# find_parents.c, stringparse.c and check_syscalls.c, we pass
# only those sources plus the necessary flags.  Libraries are
# appended at the end for proper symbol resolution.
parents:
	$(CC) $(CFLAGS) util/find_parents.c io/stringparse.c check_syscalls.c -o util/find_parents $(LDFLAGS) $(OFLAGS) $(LIBS)

# Build the subhalo statistics utility.  It depends on
# subhalo_stats.c and the rest of the CFILES used by the main build.
substats:
	$(CC) $(CFLAGS) util/subhalo_stats.c $(CFILES) -o util/subhalo_stats $(LDFLAGS) $(OFLAGS) $(LIBS)

# Remove editor backups and built binaries.  Adjust as necessary
# if additional build artifacts are created.
clean:
	rm -f *~ io/*~ inet/*~ util/*~ rockstar util/redo_bgc2 util/bgc2_to_ascii util/find_parents util/subhalo_stats librockstar.so
