#!/usr/bin/env python3
"""Merge infra kubeconfigs without losing contexts with identical source names."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def load_config(path):
    result = subprocess.run(
        ["kubectl", "config", "view", "--kubeconfig", str(path), "--raw", "--flatten", "-o", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def unique_name(name, source, used, prefix=False):
    candidate = f"{source}/{name}" if prefix or name in used else name
    index = 2
    while candidate in used:
        candidate = f"{source}/{name}-{index}"
        index += 1
    used.add(candidate)
    return candidate


def merge_configs(inputs):
    merged = {
        "apiVersion": "v1",
        "kind": "Config",
        "preferences": {},
        "clusters": [],
        "users": [],
        "contexts": [],
        "current-context": "",
    }
    names = {kind: set() for kind in ("clusters", "users", "contexts")}

    for path, infra in inputs:
        config = load_config(path)
        references = {}
        for kind in ("clusters", "users"):
            references[kind] = {}
            for entry in config.get(kind, []):
                old = entry["name"]
                if old in references[kind]:
                    raise ValueError(f"Duplicate {kind} name {old!r} in {path}")
                new = unique_name(old, path.parent.name, names[kind], prefix=infra and kind == "users")
                references[kind][old] = new
                entry["name"] = new
                merged[kind].append(entry)

        for entry in config.get("contexts", []):
            context = entry["context"]
            cluster = context["cluster"]
            if cluster not in references["clusters"]:
                raise ValueError(f"Context {entry['name']!r} in {path} references missing cluster {cluster!r}")
            name = cluster if infra else entry["name"]
            if name in names["contexts"]:
                raise ValueError(f"Context {name!r} occurs more than once (in {path}); refusing to overwrite it")
            names["contexts"].add(name)
            context["cluster"] = references["clusters"][cluster]
            if context.get("user"):
                user = context["user"]
                if user not in references["users"]:
                    raise ValueError(f"Context {entry['name']!r} in {path} references missing user {user!r}")
                context["user"] = references["users"][user]
            if config.get("current-context") == entry["name"] and not merged["current-context"]:
                merged["current-context"] = name
            entry["name"] = name
            merged["contexts"].append(entry)

    return merged


def write_config(config, output):
    fd, temporary = tempfile.mkstemp(prefix=".kubeconfig-", dir=output.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(config, stream)
            stream.write("\n")
        if output.exists():
            backup = Path(f"{output}.bkp")
            print(f"Backing up previous infra kubeconfig {output} as {backup}")
            shutil.copy2(output, backup)
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    clusters_dir = Path(sys.argv[1])
    output = Path(sys.argv[2]).expanduser()
    extras = [Path(path).expanduser() for path in sys.argv[3].split(os.pathsep) if path]
    inputs = [(path, True) for path in sorted(clusters_dir.glob("*/kubeconfig"))]
    inputs.extend((path, False) for path in extras)
    write_config(merge_configs(inputs), output)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"Failed to merge kubeconfigs: {error}")
