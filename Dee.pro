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
    qml/pages/PostWebView.qml \
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
# Rust dynamic library (liblemmy_bridge.so)
# ---------------------------------------------------------------------------

TARGET_TRIPLE = $$(SB2_RUST_TARGET_TRIPLE)
isEmpty(TARGET_TRIPLE) {
    TARGET_TRIPLE = $$(RUST_TARGET)
}

SOURCE_DIR   = $$_PRO_FILE_PWD_
RUST_STAMP   = $$SOURCE_DIR/rust/.cargo_build.stamp

isEmpty(TARGET_TRIPLE) {
    RUST_TARGET_DIR = $$SOURCE_DIR/rust/target/release
} else {
    RUST_TARGET_DIR = $$SOURCE_DIR/rust/target/$$TARGET_TRIPLE/release
}

message("Building for target: $$TARGET_TRIPLE")
message("Using Rust library dir: $$RUST_TARGET_DIR")

LIBS += -L$$RUST_TARGET_DIR -llemmy_bridge

INCLUDEPATH += $$SOURCE_DIR/src

CARGO_CMD = cd $$SOURCE_DIR && \
    cargo build --release \
        --target-dir $$SOURCE_DIR/rust/target \
        --manifest-path $$SOURCE_DIR/rust/Cargo.toml \
        --locked
!isEmpty(TARGET_TRIPLE): CARGO_CMD += --target $$TARGET_TRIPLE

# ---------------------------------------------------------------------------
# Step 1 — qmake-time bootstrap
#
# Runs cargo once, synchronously, so lemmy_bridge.h exists before make
# starts any parallel compilation. Guarded by the stamp file so that
# subsequent qmake runs (e.g. IDE refreshes) don't rebuild from scratch.
# ---------------------------------------------------------------------------
!exists($$RUST_STAMP) {
    message("Stamp not found — running cargo build at qmake time...")
    system($$CARGO_CMD && touch $$RUST_STAMP)
}

# ---------------------------------------------------------------------------
# Step 2 — make-time incremental rule
#
# Targets the stamp file, not the .so. The stamp is touched *after* cargo
# succeeds, so its mtime is always strictly newer than the Rust sources that
# triggered the rebuild. This prevents make from seeing the freshly-built
# .so as same-age as the sources and re-launching cargo a second time.
# ---------------------------------------------------------------------------
rust_cargo.target   = $$RUST_STAMP
rust_cargo.commands = $$CARGO_CMD && touch $$RUST_STAMP
rust_cargo.depends  = $$SOURCE_DIR/rust/Cargo.toml \
                      $$SOURCE_DIR/rust/src/lib.rs
QMAKE_EXTRA_TARGETS += rust_cargo

# The linker waits for the stamp, which is only written after the .so exists.
PRE_TARGETDEPS += $$RUST_STAMP

QMAKE_CLEAN += \
    $$RUST_STAMP \
    $$SOURCE_DIR/src/lemmy_bridge.h \
    $$RUST_TARGET_DIR/liblemmy_bridge.so

rust_so_install.path  = /usr/lib
rust_so_install.files = $$RUST_TARGET_DIR/liblemmy_bridge.so
INSTALLS += rust_so_install

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
