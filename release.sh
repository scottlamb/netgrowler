#!/bin/sh -e

VERSION=$1

if test "$#" != 1; then
    echo Invalid arguments.
    exit 1
fi

xcodebuild -configuration Deployment
rm -rf release NetGrowler-$VERSION.dmg netgrowler-$VERSION.tar{,.gz}
mkdir release
cp -R build/Deployment/NetGrowler.app README.html CHANGES release
cp NetGrowlerDisk.icns release/.VolumeIcon.icns
hdiutil create -srcfolder release -volname "NetGrowler $VERSION" \
               NetGrowler-$VERSION.dmg
git-archive --prefix=netgrowler-$VERSION/ HEAD > netgrowler-$VERSION.tar
gzip netgrowler-$VERSION.tar
