# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-dee

CONFIG += sailfishapp link_pkgconfig

QT += core network

PKGCONFIG += sailfishsecrets
LIBS += -lsailfishapp

INCLUDEPATH += /usr/include/Sailfish

SOURCES += src/main.cpp \
    src/lemmyapi.cpp \
    src/securestorage.cpp

HEADERS += src/lemmyapi.h \
    src/lemmy_bridge.h \
    src/securestorage.h

DISTFILES += qml/Dee.qml \
    qml/cover/CoverPage.qml \
    qml/pages/LoginPage.qml \
    qml/pages/CommunitiesPage.qml \
    qml/pages/PostPage.qml \
    qml/pages/SubscribedPage.qml \
    rpm/harbour-dee.changes.in \
    rpm/harbour-dee.changes.run.in \
    rpm/harbour-dee.spec \
    translations/*.ts \
    harbour-dee.desktop \
    rust/Cargo.toml \
    rust/src/lib.rs

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# ---------------------------------------------------------------------------
# Rust static library (liblemmy_bridge.a)
# ---------------------------------------------------------------------------
# The Rust library must be built before qmake's link step.
# Adjust RUST_TARGET_DIR if cross-compiling for a different architecture.

# Detect target triple from environment (set by RPM spec)
TARGET_TRIPLE = $$(SB2_RUST_TARGET_TRIPLE)
isEmpty(TARGET_TRIPLE) {
    TARGET_TRIPLE = $$RUST_TARGET
}

# Construct the correct target directory
SOURCE_DIR = $$_PRO_FILE_PWD_
isEmpty(TARGET_TRIPLE) {
    RUST_TARGET_DIR = $$SOURCE_DIR/rust/target/release
} else {
    RUST_TARGET_DIR = $$SOURCE_DIR/rust/target/$$TARGET_TRIPLE/release
}

message("Building for target: $$TARGET_TRIPLE")
message("Using Rust library dir: $$RUST_TARGET_DIR")

LIBS += -L$$RUST_TARGET_DIR -llemmy_bridge

# Rust's static library pulls in system deps; link them explicitly.
LIBS += -lssl -lcrypto -lpthread -ldl -lm

INCLUDEPATH += $$SOURCE_DIR/src

# Build Rust library automatically before linking
rust_cargo.target = $$RUST_TARGET_DIR/liblemmy_bridge.so
rust_cargo.commands = cd $$SOURCE_DIR && cargo build --release --target-dir rust/target --manifest-path rust/Cargo.toml --locked
!isEmpty(TARGET_TRIPLE): rust_cargo.commands += --target $$TARGET_TRIPLE
rust_cargo.depends = $$SOURCE_DIR/rust/Cargo.toml $$SOURCE_DIR/rust/src/lib.rs $$SOURCE_DIR/rust/build.rs
QMAKE_EXTRA_TARGETS += rust_cargo
PRE_TARGETDEPS += $$RUST_TARGET_DIR/liblemmy_bridge.so

library.path = /usr/lib
library.files = $$RUST_TARGET_DIR/liblemmy_bridge.so
INSTALLS += library

# ---------------------------------------------------------------------------
# Translations
# ---------------------------------------------------------------------------
# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
#TRANSLATIONS += translations/harbour-dee-de.ts
