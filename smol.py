#!/usr/bin/env python3

import argparse
import glob
import itertools
import os.path
import shutil
import subprocess
import sys

from smolshared import *
from smolparse  import *
from smolemit   import *

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-m', '--target', default='', \
        help='architecture to generate asm code for (default: auto)')
    parser.add_argument('-l', '--library', metavar='LIB', action='append', \
        help='libraries to link against')
    parser.add_argument('-L', '--libdir', metavar='DIR', action='append', \
        help="directories to search libraries in")

    parser.add_argument('--nasm', default=shutil.which('nasm'), \
        help="which nasm binary to use")
    parser.add_argument('--cc', default=shutil.which('cc'), \
        help="which cc binary to use")
    parser.add_argument('--scanelf', default=shutil.which('scanelf'), \
        help="which scanelf binary to use")
    parser.add_argument('--readelf', default=shutil.which('readelf'), \
        help="which readelf binary to use")
    parser.add_argument('input', nargs='+', help="input object file")
    parser.add_argument('output', type=argparse.FileType('w'), \
        help="output nasm file", default=sys.stdout)

    args = parser.parse_args()

    if args.libdir is None: args.libdir = []
    arch = args.target.tolower() if len(args.target)!=0 \
                                 else decide_arch(args.input)
    if arch not in archmagic:
        eprintf("Unknown architecture '" + str(arch) + "'")
        sys.exit(1)

    syms = get_needed_syms(args.readelf, args.input)

    paths = get_cc_paths(args.cc)

    spaths = args.libdir + paths['libraries']
    libraries=paths['libraries']
    libnames = args.library
    libs = list(find_libs(spaths, libnames))
    symbols = {}

    for symbol, reloc in syms:
        library = find_symbol(args.scanelf, libs, libnames, symbol)
        if not library:
            eprintf("could not find symbol: {}".format(symbol))
            sys.exit(1)
        symbols.setdefault(library, [])
        symbols[library].append((symbol, reloc))

    output(arch, symbols, args.output)

if __name__ == '__main__':
    main()

