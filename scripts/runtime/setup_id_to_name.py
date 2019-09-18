#!/usr/bin/env python3

import hmac
from hashlib import sha1
import requests
import json
import sys
import re


    
context_name = sys.argv[1]

KEY = b'stackrox!'
ENCODED_KEY = 'stackrox%21'
ORCHESTRATOR = 'Kubernetes/default/GKE'
LIFESPAN = 43200


def setupId2Hash(setup_id):
    setup_id = bytes(setup_id, "utf-8")
    return hmac.new(KEY, setup_id, sha1).hexdigest()

def maybe_parse_context_to_setup_id(context):
    match = re.match(r'^.*setup-([^-]*)', context)
    if match is None:
        return None
    try:
        return match.group(1)
    except:
        return None
    
def load_workfile_contents(workfilepath):
    try:
        with open(workfilepath, 'r') as f:
            return json.load(f)
    except:
        return {}

def get_value_to_print(context):
    setup_id = maybe_parse_context_to_setup_id(context)
    # Not a setup
    if not setup_id:
        return context

    headers = {
        "content-type": "application/json"
    }

    url = "https://setup.rox.systems/api/setup/%s/%s" % (setup_id, setupId2Hash(setup_id))
    req = requests.get(url, headers=headers)
    try:
        req.raise_for_status()
        name = json.loads(req.text)["general"]["setupName"]
        sp_name = name.split()
        return "[SETUP] " + " ".join([n for n in sp_name if not n.startswith(":") and not n.endswith(":")])
    except:
        # Any failure, just print the context
        return context


def main():
    assert len(sys.argv) >= 2, "No context found in args"
    context = sys.argv[1]
    cache = {}
    if len(sys.argv) > 2:
        cache = load_workfile_contents(sys.argv[2])
    if context in cache:
        print (cache[context])
        return
    value_to_print = get_value_to_print(context)
    print (value_to_print)
    if len(sys.argv) > 2:
        cache[context] = value_to_print
        with open(sys.argv[2], 'w') as f:
            json.dump(cache, f)


if __name__ == "__main__":
    main()
