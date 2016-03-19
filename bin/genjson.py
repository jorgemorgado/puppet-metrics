#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Generate a JSON output from a cloc/SQLite query input.
#
# Usage: sqlite3 DBFILE.db '<sql_query>' | genjson.py > output.json
#
# Author: Jorge Morgado <jorge@morgado.ch>
#

__version__ = 1.0

import sys
import re
import json
import argparse

from collections import defaultdict

version = """%(prog)s 1.0 (c)2015 jorge@morgado.ch"""
description = "Generate a JSON output from a cloc/SQLite query input."

parser = argparse.ArgumentParser(description=description)

parser.add_argument('-v', '--version', action='version', version=version)
parser.add_argument('-d', '--debug', action='store_true', dest='debug',
                    default=False, help='enable debug mode (developers only)')

args = parser.parse_args()

# Disable traceback if not in debug mode
if not args.debug:
    sys.tracebacklimit = 0


def main():
    modules = defaultdict(list)
    pattern_manifest = re.compile(r'^\.\/common\/modules\/(?P<name>.*?)\/manifests\/(?P<file>.*?)\.pp\|(?P<lines>\d+?)$')
    pattern_template = re.compile(r'^\.\/common\/modules\/(?P<name>.*?)\/templates\/(?P<file>.*?)\.erb\|(?P<lines>\d+?)$')

    for line in sys.stdin:
        # Does it matches a manifest file?
        match = pattern_manifest.match(line)
        if match:
            modulename = match.group('name')
            filelines  = match.group('lines')

            if match.group('file') == 'init':
                filename = modulename
            else:
                filename = modulename + '::' + match.group('file').replace('/', '::')

            modules[modulename].append([ filename, filelines ])


        # Does it matches a template file?
        match = pattern_template.match(line)
        if match:
            modulename = match.group('name')
            filelines  = match.group('lines')
            filename   = modulename + '/' + match.group('file') + '.erb'

            modules[modulename].append([ filename, filelines ])


    flare_children = []

    for k, v in modules.iteritems():
        #print "Module %s:" % k

        children = []

        for item in v:
            #print "\t", item[0], item[1]
            children.append({ "name": item[0], "size": int(item[1]) })

        node = { "name": k, "children": children }

        #print node
        flare_children.append(node)

    data = {
      "name": "flare",
      "children": flare_children
    }

    # Output JSON data
    print json.dumps(data)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print "Caught Ctrl-C."
        sys.exit(ERROR)
