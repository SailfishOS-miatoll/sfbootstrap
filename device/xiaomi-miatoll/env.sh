# sfbootstrap env for xiaomi-miatoll
VENDOR=xiaomi
VENDOR_PRETTY="Xiaomi"
DEVICE=miatoll
DEVICE_PRETTY="Redmi Note 9 Pro"
#HABUILD_DEVICE=$DEVICE
#HOOKS_DEVICE=$SFB_DEVICE
PORT_ARCH=aarch64
SOC=qcom
PORT_TYPE=hybris
HYBRIS_VER=18.1
ANDROID_MAJOR_VERSION=11
REPO_INIT_URL="https://github.com/SailfishOS-miatoll/android.git"
REPO_LOCAL_MANIFESTS_URL="https://github.com/SailfishOS-miatoll/local_manifests.git"
HAL_MAKE_TARGETS=(hybris-hal droidmedia bzip2 libbiometry_fp_api)
HAL_ENV_EXTRA=""
RELEASE=4.6.0.13
TOOLING_RELEASE=4.6.0.11
SDK_RELEASE=latest
REPOS=(
    'https://bitbucket.org/thexperienceproject/yuki-clang.git' prebuilts/yuki-clang "19.0.0git" 1
    'https://github.com/libhybris/libhybris.git' hybris/mw/libhybris "master" 1
)
#LINKS=()
export VENDOR DEVICE PORT_ARCH RELEASE
