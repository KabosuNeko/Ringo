cmake_minimum_required(VERSION 3.16)
project(IslandBackend VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui DBus Qml Network)

# The wallpaper engine speaks to the compositor directly, so it needs
# wayland-client plus the three protocol code generators at build time.
find_package(PkgConfig REQUIRED)
find_package(Threads REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
find_program(WAYLAND_SCANNER NAMES wayland-scanner REQUIRED)

enable_testing()

set(WALLPAPER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/backend/engines/wallpaper)
set(WALLPAPER_PROTO_DIR ${CMAKE_CURRENT_BINARY_DIR}/wallpaper-proto)

function(ringo_protocol name xml out_dir)
    add_custom_command(
        OUTPUT ${out_dir}/${name}.h ${out_dir}/${name}.c
        COMMAND ${CMAKE_COMMAND} -E make_directory ${out_dir}
        COMMAND ${WAYLAND_SCANNER} client-header ${xml} ${out_dir}/${name}.h
        COMMAND ${WAYLAND_SCANNER} private-code ${xml} ${out_dir}/${name}.c
        DEPENDS ${xml}
        COMMENT "Generating ${name} protocol code"
        VERBATIM)
endfunction()

ringo_protocol(xdg-shell-protocol ${WALLPAPER_DIR}/proto/stable/xdg-shell/xdg-shell.xml ${WALLPAPER_PROTO_DIR})
ringo_protocol(xdg-output-unstable-v1-protocol ${WALLPAPER_DIR}/proto/unstable/xdg-output/xdg-output-unstable-v1.xml ${WALLPAPER_PROTO_DIR})
ringo_protocol(wlr-layer-shell-unstable-v1-protocol ${WALLPAPER_DIR}/wlr-layer-shell-unstable-v1.xml ${WALLPAPER_PROTO_DIR})

set_source_files_properties(backend/engines/wallpaper/wallpaper.c PROPERTIES
    COMPILE_DEFINITIONS "_GNU_SOURCE"
    # Wayland listeners must accept every argument the protocol passes, so
    # unused parameters are inherent here; everything else stays enabled.
    COMPILE_OPTIONS "-Wall;-Wextra;-Wno-unused-parameter")

# The wallpaper engine includes the generated protocol headers, so the
# generators must run before it is compiled.
set_property(SOURCE backend/engines/wallpaper/wallpaper.c APPEND PROPERTY OBJECT_DEPENDS
    ${WALLPAPER_PROTO_DIR}/xdg-shell-protocol.h
    ${WALLPAPER_PROTO_DIR}/xdg-output-unstable-v1-protocol.h
    ${WALLPAPER_PROTO_DIR}/wlr-layer-shell-unstable-v1-protocol.h)

qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    PLUGIN_TARGET IslandBackendPlugin
    SOURCES
        backend/WifiController.h
        backend/WifiController.cpp
        backend/WifiNetworkModel.h
        backend/WifiNetworkModel.cpp
        backend/BluetoothPairingAgent.h
        backend/BluetoothPairingAgent.cpp
        backend/BluetoothController.h
        backend/BluetoothController.cpp
        backend/BluetoothDeviceModel.h
        backend/BluetoothDeviceModel.cpp
        backend/LockController.h
        backend/LockController.cpp
        backend/SystemMonitor.h
        backend/SystemMonitor.cpp
        backend/WeatherController.h
        backend/WeatherController.cpp
        backend/MprisController.h
        backend/MprisController.cpp
        backend/BrightnessController.h
        backend/BrightnessController.cpp
        backend/NiriController.h
        backend/NiriController.cpp
        backend/PowerProfileController.h
        backend/PowerProfileController.cpp
        backend/SoundController.h
        backend/SoundController.cpp
        backend/FuzzySearch.h
        backend/FuzzySearch.cpp
        backend/CliphistModel.h
        backend/CliphistModel.cpp
        backend/WallpaperController.h
        backend/WallpaperController.cpp
        backend/NightLightController.h
        backend/NightLightController.cpp
        backend/Notifier.h
        backend/Notifier.cpp
        backend/StateStore.h
        backend/StateStore.cpp
        backend/Tools.h
        backend/Tools.cpp
        backend/engines/wallpaper/wallpaper.c
        ${WALLPAPER_PROTO_DIR}/xdg-shell-protocol.c
        ${WALLPAPER_PROTO_DIR}/xdg-output-unstable-v1-protocol.c
        ${WALLPAPER_PROTO_DIR}/wlr-layer-shell-unstable-v1-protocol.c
)

target_compile_definitions(IslandBackend PRIVATE RINGO_VERSION="${PROJECT_VERSION}")

target_include_directories(IslandBackend PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/backend ${WALLPAPER_DIR} ${WALLPAPER_PROTO_DIR})

target_link_libraries(IslandBackend PRIVATE Qt6::Core Qt6::Gui Qt6::DBus Qt6::Qml Qt6::Network pam PkgConfig::WAYLAND_CLIENT)

set_target_properties(IslandBackend IslandBackendPlugin PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "$ORIGIN"
)

add_custom_command(TARGET IslandBackendPlugin POST_BUILD
    COMMAND sed -i "/^prefer/d" ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    COMMENT "Stripping prefer line from generated qmldir"
)

# Wallpaper scaling-mode tests: drive the engine's static image_* helpers
# directly (the test #includes wallpaper.c), so the maths is exercised with no
# compositor, display server, root or network. The generated protocol sources
# are linked in because the engine references their symbols.
add_executable(test_wallpaper_modes
    tests/test_wallpaper_modes.c
    ${WALLPAPER_PROTO_DIR}/xdg-shell-protocol.c
    ${WALLPAPER_PROTO_DIR}/xdg-output-unstable-v1-protocol.c
    ${WALLPAPER_PROTO_DIR}/wlr-layer-shell-unstable-v1-protocol.c)

target_compile_definitions(test_wallpaper_modes PRIVATE _GNU_SOURCE)

target_include_directories(test_wallpaper_modes PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/backend ${WALLPAPER_DIR} ${WALLPAPER_PROTO_DIR})

target_link_libraries(test_wallpaper_modes PRIVATE
    PkgConfig::WAYLAND_CLIENT m Threads::Threads)

add_test(NAME wallpaper_modes COMMAND test_wallpaper_modes)
