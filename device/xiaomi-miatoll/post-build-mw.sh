sfb_build_packages --build=./hybris/droid-system-miatoll/ && \
sfb_build_packages --mw=https://github.com/SailfishOS-miatoll/sailfish-device-encryption-community.git && \
sfb_build_packages --build=hybris/mw/sailfish-fpd-community --spec=rpm/droid-biometry-fp.spec --do-not-install && \
sfb_build_packages --mw=https://github.com/mentaljam/harbour-storeman.git

