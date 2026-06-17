#!/bin/bash
set -xeuo pipefail

# fetch repos from in-cluster mirrors if we're running in OpenShift CI
if [ "${OPENSHIFT_CI}" != 0 ]; then
    ci/get-ocp-repo.sh ocp.repo
fi

. /etc/os-release
extensions_yaml="extensions/${ID}-${VERSION_ID}.yaml"
# Replace the __OCP_VERSION__ placeholder with the actual OpenShift version.
# This allows the same YAML file to be used across different OCP versions
# (e.g. 4.23 and 5.0) without duplication.
sed -i "s/__OCP_VERSION__/${OPENSHIFT_VERSION}/g" "$extensions_yaml"

# Build extensions using dnf to download packages.
# This uses repos from /etc/yum.repos.d/ and ignores repos: sections in the YAML.
mkdir -p /usr/share/rpm-ostree/extensions/

cat > /tmp/build_extensions.py <<'PYSCRIPT'
import yaml
import subprocess
import sys
import os

extensions_yaml = sys.argv[1]

print(f"Loading extensions from {extensions_yaml}")
with open(extensions_yaml) as f:
    config = yaml.safe_load(f)

extensions = config.get("extensions", {})
print(f"Found {len(extensions)} extensions")

for ext_name, ext_config in extensions.items():
    if not isinstance(ext_config, dict):
        continue

    packages = ext_config.get("packages", [])
    if not packages:
        continue

    # Check architecture filter if specified
    if "architectures" in ext_config:
        archs = ext_config["architectures"]
        current_arch = os.uname().machine
        if current_arch not in archs:
            print(f"Skipping {ext_name}: architecture {current_arch} not in {archs}")
            continue

    print(f"Downloading extension: {ext_name}")
    print(f"  Packages: {', '.join(packages)}")
    sys.stdout.flush()

    # Use dnf download to get RPMs with all dependencies
    # Disable subscription-manager plugin to avoid hangs
    cmd = ["dnf", "download", "--disableplugin=subscription-manager", "--resolve", "--alldeps", "--destdir=/usr/share/rpm-ostree/extensions/"] + packages
    print(f"  Running: {' '.join(cmd)}")
    sys.stdout.flush()

    # Don't capture output so we can see dnf progress
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print(f"Error downloading {ext_name}", file=sys.stderr)
        sys.exit(1)

    print(f"  Downloaded successfully")

print("All extensions downloaded to /usr/share/rpm-ostree/extensions/")
PYSCRIPT

python3 /tmp/build_extensions.py "$extensions_yaml"
