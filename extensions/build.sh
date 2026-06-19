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

# ipsec extension
dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
    --arch="${arch}" --arch=noarch --destdir="${destdir}" \
    libreswan NetworkManager-libreswan openvswitch3.5-ipsec

# usbguard extension
dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
    --arch="${arch}" --arch=noarch --destdir="${destdir}" \
    usbguard

# kerberos extension
dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
    --arch="${arch}" --arch=noarch --destdir="${destdir}" \
    krb5-workstation libkadm5

# sysstat extension
dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
    --arch="${arch}" --arch=noarch --destdir="${destdir}" \
    sysstat

# kernel-devel and kernel extensions (pinned to installed kernel version)
# Include epoch (0:) so dnf can disambiguate name from version in NEVRA format
kernel_evr=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' kernel)
dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
    --arch="${arch}" --arch=noarch --destdir="${destdir}" \
    "kernel-devel-0:${kernel_evr}" "kernel-headers-0:${kernel_evr}" \
    "kernel-0:${kernel_evr}" "kernel-core-0:${kernel_evr}" \
    "kernel-modules-0:${kernel_evr}" "kernel-modules-extra-0:${kernel_evr}"

# kernel-rt extension (x86_64 only, pinned to installed kernel version)
if [ "${arch}" = "x86_64" ]; then
    dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
        --arch="${arch}" --arch=noarch --destdir="${destdir}" \
        "kernel-rt-core-0:${kernel_evr}" "kernel-rt-modules-0:${kernel_evr}" \
        "kernel-rt-modules-extra-0:${kernel_evr}" "kernel-rt-devel-0:${kernel_evr}"
fi

# kernel-64k extension (aarch64 only)
if [ "${arch}" = "aarch64" ]; then
    dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
        --arch="${arch}" --arch=noarch --destdir="${destdir}" \
        "kernel-64k-core-0:${kernel_evr}" "kernel-64k-modules-0:${kernel_evr}" \
        "kernel-64k-modules-core-0:${kernel_evr}" "kernel-64k-modules-extra-0:${kernel_evr}"
fi

# two-node-ha extension (RHEL only)
if [ "$ID" = "rhel" ]; then
    dnf --repo="${YUM_REPO_NAMES}" download --resolve --alldeps \
        --arch="${arch}" --arch=noarch --destdir="${destdir}" \
        pacemaker pcs fence-agents-all
fi
