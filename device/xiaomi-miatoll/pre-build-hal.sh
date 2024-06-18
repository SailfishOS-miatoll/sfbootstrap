hybris-patches/apply-patches.sh --mb

# Temp: Apply fix build hybris-18.1 patches
$ANDROID_ROOT/miatoll_patches/miatoll_patches.sh

# AudioPolicyService is needed to avoid camera HAL dying after attempting to record video
#if ! grep -q 'AUDIOPOLICYSERVICE' "$ANDROID_ROOT/external/droidmedia/env.mk"; then
#    echo "MINIMEDIA_AUDIOPOLICYSERVICE_ENABLE := 1" > "$ANDROID_ROOT/external/droidmedia/env.mk"
#fi
