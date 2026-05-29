"""EVO-040 smoke coverage for PieFed response normalization."""

import os
import shlex
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PIEFED_CLIENT_CPP = (ROOT / "src" / "piefedclient.cpp").read_text()


def extract_function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    assert start >= 0, f"missing function {signature}"
    brace = source.find("{", start)
    assert brace >= 0, f"missing function body for {signature}"

    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    raise AssertionError(f"unterminated function body for {signature}")


def qt_compile_flags() -> list[str]:
    if not shutil.which("pkg-config"):
        pytest.skip("pkg-config is required for C++ smoke test")

    for packages in (("Qt5Core", "Qt5Network"), ("Qt6Core", "Qt6Network")):
        result = subprocess.run(
            ["pkg-config", "--cflags", "--libs", *packages],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if result.returncode == 0:
            return shlex.split(result.stdout)
    pytest.skip("Qt Core/Network development packages are required for C++ smoke test")


def test_evo040_marker_is_removed_after_normalization_gap_is_closed() -> None:
    assert "TODO(EVO-040)" not in PIEFED_CLIENT_CPP


def test_operations_route_responses_through_shape_normalizers() -> None:
    operation_normalizers = {
        "getSite": "normalizeSite",
        "listPosts": "normalizePosts",
        "listComments": "normalizeComments",
        "getPost": "normalizePostResponse",
        "likePost": "normalizePostResponse",
        "likeComment": "normalizeCommentResponse",
        "createComment": "normalizeCommentResponse",
        "listCommunities": "normalizeCommunities",
        "getCommunity": "normalizeCommunityResponse",
        "getPerson": "normalizeUserResponse",
        "search": "normalizeSearch",
        "followCommunity": "normalizeCommunityResponse",
    }

    for operation, normalizer in operation_normalizers.items():
        body = extract_function_body(
            PIEFED_CLIENT_CPP, f"void PieFedClient::{operation}"
        )
        assert f"return {normalizer}(response);" in body


def test_representative_piefed_json_normalizes_to_lemmy_qml_shape(tmp_path: Path) -> None:
    compiler = shlex.split(os.environ.get("CXX", "c++"))
    if not shutil.which(compiler[0]):
        pytest.skip(f"{compiler[0]} is required for C++ smoke test")

    source = tmp_path / "piefed_normalization_smoke.cpp"
    binary = tmp_path / "piefed_normalization_smoke"
    source.write_text(
        r'''
#include <cstdlib>
#include <functional>
#include <iostream>

#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QObject>
#include <QString>

#undef Q_OBJECT
#define Q_OBJECT
#define private public
#include "src/piefedclient.h"
#undef private
#include "src/piefedclient.cpp"

void PieFedClient::loginFinished(const QString &) {}
void PieFedClient::getSiteFinished(const QString &) {}
void PieFedClient::listPostsFinished(const QString &) {}
void PieFedClient::listCommentsFinished(const QString &) {}
void PieFedClient::getPostFinished(const QString &) {}
void PieFedClient::likePostFinished(const QString &) {}
void PieFedClient::likeCommentFinished(const QString &) {}
void PieFedClient::createCommentFinished(const QString &) {}
void PieFedClient::listCommunitiesFinished(const QString &) {}
void PieFedClient::getCommunityFinished(const QString &) {}
void PieFedClient::getPersonFinished(const QString &) {}
void PieFedClient::searchFinished(const QString &) {}
void PieFedClient::followCommunityFinished(const QString &) {}

static void require(bool condition, const char *message) {
  if (!condition) {
    std::cerr << message << std::endl;
    std::exit(1);
  }
}

static QJsonObject jsonObject(const char *json) {
  QJsonDocument doc = QJsonDocument::fromJson(QByteArray(json));
  require(doc.isObject(), "test fixture JSON must be an object");
  return doc.object();
}

static QJsonObject objectAt(const QJsonObject &obj, const char *key) {
  return obj.value(QString::fromLatin1(key)).toObject();
}

static QJsonArray arrayAt(const QJsonObject &obj, const char *key) {
  return obj.value(QString::fromLatin1(key)).toArray();
}

int main(int argc, char **argv) {
  QCoreApplication app(argc, argv);
  PieFedClient client;

  QJsonObject postResponse = client.normalizePostResponse(jsonObject(R"json({
    "post_view": {
      "post": {"id": 1, "title": "PieFed title", "user_id": 11, "sticky": true, "instance_sticky": true},
      "creator": {"id": 11, "user_name": "alice", "actor_id": "https://piefed.example/u/alice"},
      "community": {"id": 2, "name": "main", "counts": {"subscriptions_count": 7, "post_count": 8, "post_reply_count": 9}},
      "counts": {"score": 5, "comments": 9}
    },
    "community_view": {"community": {"id": 2, "name": "main"}, "counts": {"subscriptions_count": 33}},
    "moderators": [{"moderator": {"id": 20, "user_name": "mod"}, "community": {"id": 2, "name": "main", "counts": {"post_count": 8}}}],
    "cross_posts": [{"post": {"id": 3, "title": "Cross title", "user_id": 12}, "creator": {"id": 12, "user_name": "carol"}}]
  })json"));
  QJsonObject postView = objectAt(postResponse, "post_view");
  QJsonObject post = objectAt(postView, "post");
  require(post.value("name").toString() == "PieFed title", "post title should become Lemmy post.name");
  require(post.value("creator_id").toInt() == 11, "post user_id should become creator_id");
  require(post.value("featured_community").toBool(), "sticky post should expose featured_community");
  require(post.value("featured_local").toBool(), "instance_sticky post should expose featured_local");
  require(objectAt(postView, "creator").value("name").toString() == "alice", "post creator user_name should become name");
  require(objectAt(objectAt(postView, "community"), "counts").value("subscribers").toInt() == 7, "post community subscriptions_count should become subscribers");
  require(objectAt(objectAt(postResponse, "community_view"), "counts").value("subscribers").toInt() == 33, "post response community_view should be normalized");
  require(objectAt(arrayAt(postResponse, "moderators").first().toObject(), "moderator").value("name").toString() == "mod", "post response moderators should be normalized");
  require(objectAt(arrayAt(postResponse, "cross_posts").first().toObject(), "post").value("name").toString() == "Cross title", "post response cross_posts should be normalized");

  QJsonObject commentResponse = client.normalizeCommentResponse(jsonObject(R"json({
    "comment_view": {
      "comment": {"id": 4, "body": "Comment body", "user_id": 11},
      "post": {"id": 1, "title": "PieFed title", "user_id": 11},
      "creator": {"id": 11, "user_name": "alice"},
      "community": {"id": 2, "name": "main", "counts": {"post_reply_count": 9}}
    }
  })json"));
  QJsonObject commentView = objectAt(commentResponse, "comment_view");
  QJsonObject comment = objectAt(commentView, "comment");
  require(comment.value("content").toString() == "Comment body", "comment body should become content");
  require(comment.value("creator_id").toInt() == 11, "comment user_id should become creator_id");
  require(objectAt(commentView, "post").value("name").toString() == "PieFed title", "comment response nested post should be normalized");
  require(objectAt(commentView, "creator").value("name").toString() == "alice", "comment response creator should be normalized");

  QJsonObject search = client.normalizeSearch(jsonObject(R"json({
    "posts": [{"post": {"id": 5, "title": "Search post", "user_id": 30}, "creator": {"id": 30, "user_name": "poster"}}],
    "comments": [{"comment": {"id": 6, "body": "Search comment", "user_id": 31}, "post": {"id": 5, "title": "Search post"}}],
    "communities": [{"community": {"id": 7, "name": "ask"}, "counts": {"subscriptions_count": 44, "active_daily": 3}}],
    "users": [{"person": {"id": 8, "user_name": "person"}}]
  })json"));
  require(objectAt(arrayAt(search, "posts").first().toObject(), "post").value("name").toString() == "Search post", "search posts should be normalized");
  require(objectAt(arrayAt(search, "comments").first().toObject(), "comment").value("content").toString() == "Search comment", "search comments should be normalized");
  QJsonObject searchCommunityCounts = objectAt(arrayAt(search, "communities").first().toObject(), "counts");
  require(searchCommunityCounts.value("subscribers").toInt() == 44, "search communities should expose subscribers");
  require(searchCommunityCounts.value("users_active_day").toInt() == 3, "search communities should expose users_active_day");
  require(objectAt(arrayAt(search, "users").first().toObject(), "person").value("name").toString() == "person", "search users should be normalized");

  QJsonObject site = client.normalizeSite(jsonObject(R"json({
    "site": {"name": "PieFed", "user_count": 42},
    "admins": [{"person": {"id": 9, "user_name": "admin"}}]
  })json"));
  require(objectAt(objectAt(site, "site_view"), "counts").value("users").toInt() == 42, "site user_count should become site_view counts.users");
  require(objectAt(arrayAt(site, "admins").first().toObject(), "person").value("name").toString() == "admin", "site admins should be normalized");

  return 0;
}
'''
    )

    compile_result = subprocess.run(
        [
            *compiler,
            "-std=c++11",
            "-fPIC",
            "-I",
            str(ROOT),
            str(source),
            "-o",
            str(binary),
            *qt_compile_flags(),
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert compile_result.returncode == 0, compile_result.stderr

    run_result = subprocess.run(
        [str(binary)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert run_result.returncode == 0, run_result.stderr
