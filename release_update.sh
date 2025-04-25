. ~/.hadk.env
rm -rf /srv/http/$RELEASE/$VENDOR-$DEVICE/$PORT_ARCH
mkdir -p /srv/http/$RELEASE/$VENDOR-$DEVICE
cp -ar src/hybris-18.1/droid-local-repo/$DEVICE \
/srv/http/$RELEASE/$VENDOR-$DEVICE/$PORT_ARCH
rm -rf /srv/http/$RELEASE/$VENDOR-$DEVICE/$PORT_ARCH/repo
rm -rf /srv/http/$RELEASE/xiaomi-miatoll/aarch64/droid-system-*
chroot/sdks/sfossdk/sdk-chroot createrepo_c /parentroot/srv/http/$RELEASE/$VENDOR-$DEVICE/$PORT_ARCH
