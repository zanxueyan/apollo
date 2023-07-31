#!/usr/bin/env bash

###############################################################################
# Copyright 2018 The Apollo Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

# Fail on first error.
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"
. ./installer_base.sh

# Note(storypku):
# libgeos-dev for shapely
# libhdf5-dev for h5py

apt_get_update_and_install \
    libgeos-dev \
    libhdf5-dev

# libc6-dev
[[ -f /usr/include/xlocale.h ]] || ln -s /usr/include/locale.h /usr/include/xlocale.h

pip3_install -r py3_requirements.txt

# Since pypcd installed via `pip install` only works with python2.7,
# we can only install it this way
git clone https://github.com/dimatura/pypcd
pushd pypcd >/dev/null
git fetch origin pull/9/head:python3
git checkout python3
python3 setup.py install --user
popd >/dev/null
rm -rf pypcd

if [[ -n "${CLEAN_DEPS}" ]]; then
    apt_get_remove libhdf5-dev
    apt_get_update_and_install \
        libhdf5-100
fi

# Clean up cache to reduce layer size.
apt-get clean && \
    rm -rf /var/lib/apt/lists/*
