#!/bin/bash
set -xeuo pipefail

# fetch repos from in-cluster mirrors if we're running in OpenShift CI
if [ "${OPENSHIFT_CI}" != 0 ]; then
    ci/get-ocp-repo.sh ocp.repo
fi

# add all the repos from the src dir (including mounted secret.repo)
# into /etc/yum.repos.d so dnf sees them
cat /os/*.repo >> /etc/yum.repos.d/git.repo

. /etc/os-release
arch=$(uname -m)
destdir=/usr/share/rpm-ostree/extensions/
mkdir -p "${destdir}"

# Helper function to download packages from a package list file
download_packages() {
    local package_file=$1
    local packages

    # Read package file and perform variable substitution
    # This allows ${kernel_evr} in package files to be expanded
    packages=$(envsubst < "extensions/${package_file}")

    # Download the packages
    dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
        --arch="${arch}" --arch=noarch --destdir="${destdir}" \
        ${packages}
}

# ipsec extension
download_packages "packages-ipsec.txt"

# usbguard extension
download_packages "packages-usbguard.txt"

# kerberos extension
download_packages "packages-kerberos.txt"

# sysstat extension
download_packages "packages-sysstat.txt"

# kernel-devel and kernel extensions (pinned to installed kernel version)
# Include epoch (0:) so dnf can disambiguate name from version in NEVRA format
kernel_evr=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' kernel)
download_packages "packages-kernel-devel.txt"

# kernel-rt extension (x86_64 only, pinned to installed kernel version)
if [ "${arch}" = "x86_64" ]; then
    download_packages "packages-kernel-rt.txt"
fi

# kernel-64k extension (aarch64 only)
if [ "${arch}" = "aarch64" ]; then
    download_packages "packages-kernel-64k.txt"
fi

# two-node-ha extension (RHEL only)
if [ "$ID" = "rhel" ]; then
    download_packages "packages-two-node-ha.txt"
fi
