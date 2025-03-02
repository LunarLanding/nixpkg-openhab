#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq ripgrep gawk git

set -eux
set -o pipefail

readarray -t RELEASES <<<"$(curl https://api.github.com/repos/openhab/openhab-distro/tags | jq -r '.[].name' | rg '^\d+\.\d+\.\d+*$')"
MOST_RECENT=${RELEASES[0]}

# Sometimes GitHub returns a response containing something unusual, and although `jq` fails with
# the error:
#
#   jq: error (at <stdin>:1): Cannot index string with string "name"
#
# the processing does not stop despite `pipefail`. In those instances `$MOST_RECENT` ends up empty,
# so lets just bail when that happens.
if [[ -z "$MOST_RECENT" ]]; then
    exit 1
fi

echo -n "$MOST_RECENT" > version
curl -L https://github.com/openhab/openhab-distro/releases/download/"$MOST_RECENT"/openhab-"$MOST_RECENT".tar.gz \
    | sha256sum \
    | cut -d" " -f1 \
    | tr -d '\n' \
    > openhab.sha256

curl -L https://github.com/openhab/openhab-distro/releases/download/"$MOST_RECENT"/openhab-addons-"$MOST_RECENT".kar \
    | sha256sum \
    | cut -d" " -f1 \
    | tr -d '\n' \
    > openhab-addons.sha256

if git diff --quiet "version"; then
    exit 0
fi

if [[ -v GITHUB_OUTPUT ]]; then
    echo "version=$MOST_RECENT" >> $GITHUB_OUTPUT
    echo "changed=true" >> $GITHUB_OUTPUT
fi

# Make a commit that we'll PR
NAME=nixpkg-openhab-auto-update[bot]
MAIL="GitHub <noreply@github.com>"
git add version openhab.sha256 openhab-addons.sha256
git -c user.name="$NAME" -c user.email="$MAIL" commit -m "openhab: ? -> $MOST_RECENT"
