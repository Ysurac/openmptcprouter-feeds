#!/usr/bin/env python3
"""
Generate protocols.json from nDPI source files at package build time.
Usage: gen-protocols.py <ndpi_src_dir> <output.json>
"""

import sys
import re
import json


def parse_category_enum(typedefs_h):
    """Parse NDPI_PROTOCOL_CATEGORY_XXX enum → integer index.

    The enum opens as 'typedef enum {' on one line and closes as
    '} ndpi_protocol_category_t' on another, so we anchor on the first
    NDPI_PROTOCOL_CATEGORY_UNSPECIFIED entry (always = 0) to start.
    """
    cats = {}
    in_enum = False
    counter = 0
    try:
        with open(typedefs_h) as f:
            for line in f:
                # Start collecting at the first category entry (= 0)
                if not in_enum and 'NDPI_PROTOCOL_CATEGORY_UNSPECIFIED' in line:
                    in_enum = True
                if in_enum:
                    if '} ndpi_protocol_category_t' in line:
                        break
                    m = re.match(r'\s*NDPI_PROTOCOL_CATEGORY_([A-Z0-9_]+)\s*(?:=\s*(\d+))?', line)
                    if m:
                        name = m.group(1)
                        if m.group(2) is not None:
                            counter = int(m.group(2))
                        cats[name] = counter
                        counter += 1
    except FileNotFoundError:
        pass
    return cats


def parse_category_strings(ndpi_main_c):
    """Parse the static categories[] string array → index to display name."""
    strings = {}
    in_array = False
    idx = 0
    try:
        with open(ndpi_main_c) as f:
            for line in f:
                if 'static const char *categories[' in line:
                    in_array = True
                    idx = 0
                    continue
                if in_array:
                    if '};' in line:
                        break
                    m = re.search(r'"([^"]*)"', line)
                    if m:
                        strings[idx] = m.group(1)
                        idx += 1
    except FileNotFoundError:
        pass
    return strings


def parse_protocols(ndpi_main_c):
    """Parse ndpi_set_proto_defaults calls to extract protocol metadata."""
    protos = []
    try:
        lines = open(ndpi_main_c).readlines()
    except FileNotFoundError:
        return protos

    i = 0
    while i < len(lines):
        line = lines[i]
        if 'ndpi_set_proto_defaults(ndpi_str,' in line:
            is_app = '1 /* app proto */' in line
            is_cleartext = '1 /* cleartext */' in line
            # Name and category are on the next line
            j = i + 1
            while j < len(lines) and lines[j].strip() == '':
                j += 1
            if j < len(lines):
                next_line = lines[j]
                nm  = re.search(r'"([^"]+)"', next_line)
                cat = re.search(r'NDPI_PROTOCOL_CATEGORY_([A-Z0-9_]+)', next_line)
                if nm and cat and nm.group(1) not in ('Unknown', ''):
                    protos.append({
                        'name':          nm.group(1),
                        'category_enum': cat.group(1),
                        'app':           is_app,
                        'cleartext':     is_cleartext,
                    })
        i += 1
    return protos


def category_display(enum_name, cat_enum_to_idx, cat_idx_to_str):
    idx = cat_enum_to_idx.get(enum_name)
    if idx is not None:
        s = cat_idx_to_str.get(idx, '')
        if s:
            return s
    # Fallback: normalize enum suffix
    return enum_name.replace('_', ' ').title()


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <ndpi_src_dir> <output.json>", file=sys.stderr)
        sys.exit(1)

    ndpi_dir = sys.argv[1]
    output   = sys.argv[2]

    typedefs = f"{ndpi_dir}/src/include/ndpi_typedefs.h"
    main_c   = f"{ndpi_dir}/src/lib/ndpi_main.c"

    cat_enum_to_idx = parse_category_enum(typedefs)
    cat_idx_to_str  = parse_category_strings(main_c)
    raw_protos      = parse_protocols(main_c)

    # Deduplicate by name, keeping first occurrence
    seen      = set()
    proto_out = []
    for p in raw_protos:
        if p['name'] in seen:
            continue
        seen.add(p['name'])
        cat = category_display(p['category_enum'], cat_enum_to_idx, cat_idx_to_str)
        proto_out.append({
            'name':      p['name'],
            'category':  cat,
            'app':       p['app'],
            'cleartext': p['cleartext'],
        })
    proto_out.sort(key=lambda x: x['name'].lower())

    # Unique sorted category display names
    cat_names = sorted({p['category'] for p in proto_out if p['category']})

    result = {
        'protocols':  proto_out,
        'categories': cat_names,
    }

    with open(output, 'w') as f:
        json.dump(result, f, separators=(',', ':'))

    print(f"Generated {len(proto_out)} protocols across {len(cat_names)} categories → {output}")


if __name__ == '__main__':
    main()
