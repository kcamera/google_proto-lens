#!/usr/bin/env bash
# A script for running Cabal on all the individual packages in this project.

set -euo pipefail

# List all the packages in this repo.  Put proto-lens[-protoc] first since
# they're dependencies of the others.  (Unfortunately, "stack query" doesn't
# give them to us in the right order.)
BASE_PACKAGES="proto-lens proto-lens-protoc"
OTHER_PACKAGES=$(stack query | sed -n 's/  \(.*\):$/\1/p' | sed '/^proto-lens$/d' | sed '/^proto-lens-protoc$/d')
PACKAGES=$(echo $BASE_PACKAGES $OTHER_PACKAGES)

echo Building: $PACKAGES

# Needed by haskell-src-exts which is a dependency of proto-lens-protoc.
# Sadly, Cabal won't install such build-tools automatically.
cabal install happy

# Unregister the already-installed packages, since otherwise they may
# propagate between builds.
# TODO: use a Cabal sandbox for this.
for p in $PACKAGES
do
  echo "Unregistering $p"
  ghc-pkg unregister --force $p || true
done

for p in $PACKAGES
do
    echo "Cabal building $p"
    (cd $p &&
        cabal clean
        cabal install --enable-tests --only-dependencies
        cabal configure --enable-tests
        cabal build
        cabal sdist
        SRC_TGZ=$(cabal info . | awk '{print $2 ".tar.gz"; exit}')
        cd dist
        if [ -f "$SRC_TGZ" ]; then
            cabal install --force-reinstalls "$SRC_TGZ"
        else
            echo "expected '$SRC_TGZ' not found"
            exit 1
        fi
    )
done
