#
# CMake defines to cross-compile to ARM/Linux on BCM2708 using glibc.
#

SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_C_COMPILER arm-openwrt-linux-uclibcgnueabi-gcc)
SET(CMAKE_CXX_COMPILER arm-openwrt-linux-uclibcgnueabi-g++)
SET(CMAKE_ASM_COMPILER arm-openwrt-linux-uclibcgnueabi-gcc)
SET(CMAKE_SYSTEM_PROCESSOR arm)

add_definitions("-mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=soft")

# rdynamic means the backtrace should work
IF (CMAKE_BUILD_TYPE MATCHES "Debug")
   add_definitions(-rdynamic)
ENDIF()

# avoids annoying and pointless warnings from gcc
SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -U_FORTIFY_SOURCE")
SET(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -c")
