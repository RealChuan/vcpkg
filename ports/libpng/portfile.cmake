# Download the apng patch
set(LIBPNG_APNG_PATCH_PATH "")
if ("apng" IN_LIST FEATURES)
    if(VCPKG_HOST_IS_WINDOWS)
        # Get (g)awk and gzip installed
        vcpkg_acquire_msys(MSYS_ROOT PACKAGES gawk gzip)
        set(AWK_EXE_PATH "${MSYS_ROOT}/usr/bin")
        vcpkg_add_to_path("${AWK_EXE_PATH}")
    endif()

    set(LIBPNG_APNG_PATCH_NAME "libpng-${VERSION}-apng.patch")
    vcpkg_download_distfile(LIBPNG_APNG_PATCH_ARCHIVE
        URLS "https://downloads.sourceforge.net/project/libpng-apng/libpng16/${VERSION}/${LIBPNG_APNG_PATCH_NAME}.gz"
        FILENAME "${LIBPNG_APNG_PATCH_NAME}.gz"
        SHA512 f9b3b5ef42a7d3e61b435af69e04174c9ea6319d8fc8b5fd3443a3a9f0a0e9803bc2b0fe6658a91d0a76b06dfd846d29b63edffebeedd1cb26f4d2cf0c87f8b1
    )
    set(LIBPNG_APNG_PATCH_PATH "${CURRENT_BUILDTREES_DIR}/src/${LIBPNG_APNG_PATCH_NAME}")
    if (NOT EXISTS "${LIBPNG_APNG_PATCH_PATH}")
        file(INSTALL "${LIBPNG_APNG_PATCH_ARCHIVE}" DESTINATION "${CURRENT_BUILDTREES_DIR}/src")
        vcpkg_execute_required_process(
            COMMAND gzip -d "${LIBPNG_APNG_PATCH_NAME}.gz"
            WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/src"
            ALLOW_IN_DOWNLOAD_MODE
            LOGNAME extract-patch.log
        )
    endif()
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pnggroup/libpng
    REF v${VERSION}
    SHA512 34c806e0dda960b480ce2f5ea13e2e55a9540f07c51948be25d312b901c431bc814f730f9322a2e3b6f88d4104a0c49bde9e616762b342d07db44e2c7fd5f2dc
    HEAD_REF master
    PATCHES
        "${LIBPNG_APNG_PATCH_PATH}"
        cmake.patch
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" PNG_SHARED)
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" PNG_STATIC)

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools PNG_TOOLS
    INVERTED_FEATURES
        tools SKIP_INSTALL_PROGRAMS
)

vcpkg_list(SET LIBPNG_HARDWARE_OPTIMIZATIONS_OPTION)
if(VCPKG_TARGET_IS_IOS)
    vcpkg_list(APPEND LIBPNG_HARDWARE_OPTIMIZATIONS_OPTION "-DPNG_HARDWARE_OPTIMIZATIONS=OFF")
endif()

vcpkg_list(SET LD_VERSION_SCRIPT_OPTION)
if(VCPKG_TARGET_IS_ANDROID)
    vcpkg_list(APPEND LD_VERSION_SCRIPT_OPTION "-Dld-version-script=OFF")
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        vcpkg_cmake_get_vars(cmake_vars_file)
        include("${cmake_vars_file}")
        if(VCPKG_DETECTED_CMAKE_ANDROID_ARM_NEON)
            vcpkg_list(APPEND LIBPNG_HARDWARE_OPTIMIZATIONS_OPTION "-DPNG_ARM_NEON=on")
        else()
            # for armeabi-v7a, check whether NEON is available
            vcpkg_list(APPEND LIBPNG_HARDWARE_OPTIMIZATIONS_OPTION "-DPNG_ARM_NEON=check")
        endif()
    endif()
endif()

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" AND VCPKG_TARGET_IS_LINUX)
  vcpkg_list(APPEND LIBPNG_HARDWARE_OPTIMIZATIONS_OPTION "-DPNG_ARM_NEON=on")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${LIBPNG_HARDWARE_OPTIMIZATIONS_OPTION}
        ${LD_VERSION_SCRIPT_OPTION}
        -DPNG_STATIC=${PNG_STATIC}
        -DPNG_SHARED=${PNG_SHARED}
        -DPNG_FRAMEWORK=OFF
        -DPNG_TESTS=OFF
        -DSKIP_INSTALL_EXECUTABLES=ON
        -DSKIP_INSTALL_FILES=OFF
        ${FEATURE_OPTIONS}
    OPTIONS_DEBUG
        -DSKIP_INSTALL_HEADERS=ON
    MAYBE_UNUSED_VARIABLES
        PNG_ARM_NEON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME png CONFIG_PATH lib/cmake/PNG)
vcpkg_cmake_config_fixup(CONFIG_PATH lib/libpng)
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/png")

# unofficial legacy usage
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/libpng-config.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_fixup_pkgconfig()
if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    if(NOT VCPKG_BUILD_TYPE)
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/libpng16.pc" "-lpng16" "-llibpng16d")
        file(INSTALL "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/libpng16.pc" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig" RENAME "libpng.pc")
    endif()
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/lib/pkgconfig/libpng16.pc" "-lpng16" "-llibpng16")
elseif(NOT VCPKG_BUILD_TYPE)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/libpng16.pc" "-lpng16" "-lpng16d")
    file(INSTALL "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/libpng16.pc" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig" RENAME "libpng.pc")
endif()
file(INSTALL "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/libpng16.pc" DESTINATION "${CURRENT_PACKAGES_DIR}/lib/pkgconfig" RENAME "libpng.pc")

vcpkg_copy_pdbs()

if(PNG_TOOLS)
    vcpkg_copy_tools(TOOL_NAMES "pngfix" "png-fix-itxt" AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
