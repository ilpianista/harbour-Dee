TARGET = harbour-dee

CONFIG += sailfishapp

QT += core network

PKGCONFIG += sailfishsecrets

INCLUDEPATH += /usr/include/Sailfish

SOURCES += src/main.cpp \
    src/lemmyapi.cpp \
    src/postsmodel.cpp \
    src/securestorage.cpp

HEADERS += src/lemmyapi.h \
    src/lemmy_bridge.h \
    src/postsmodel.h \
    src/securestorage.h

DISTFILES += qml/Dee.qml \
    qml/cover/CoverPage.qml \
    qml/pages/LoginPage.qml \
    qml/pages/CommunitiesPage.qml \
    qml/pages/PostPage.qml \
    qml/pages/PostWebView.qml \
    qml/pages/SubscribedPage.qml \
    qml/pages/utils.js \
    rpm/harbour-dee.changes \
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

SOURCE_DIR = $$_PRO_FILE_PWD_
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

!exists($$SOURCE_DIR/src/lemmy_bridge.h) {
    message("lemmy_bridge.h not found — running cargo build at qmake time...")
    system($$CARGO_CMD)
}

rust_so.target   = $$RUST_TARGET_DIR/liblemmy_bridge.so
rust_so.commands = $$CARGO_CMD
rust_so.depends  = $$SOURCE_DIR/rust/Cargo.toml \
                   $$SOURCE_DIR/rust/src/lib.rs
QMAKE_EXTRA_TARGETS += rust_so
PRE_TARGETDEPS  += $$RUST_TARGET_DIR/liblemmy_bridge.so

QMAKE_CLEAN += \
    $$SOURCE_DIR/src/lemmy_bridge.h \
    $$RUST_TARGET_DIR/liblemmy_bridge.so

rust_so_install.path  = /usr/share/harbour-dee/lib
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
TRANSLATIONS += translations/harbour-dee-de.ts \
                translations/harbour-dee-et.ts \
                translations/harbour-dee-fi.ts \
                translations/harbour-dee-it.ts \
                translations/harbour-dee-nb_NO.ts
