"""Static EVO-010 contract checks without adding Qt test-only indirection."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEMMY_API_CPP = (ROOT / "src" / "lemmyapi.cpp").read_text()
LEMMY_API_H = (ROOT / "src" / "lemmyapi.h").read_text()
PIEFED_CLIENT_CPP = (ROOT / "src" / "piefedclient.cpp").read_text()
PIEFED_CLIENT_H = (ROOT / "src" / "piefedclient.h").read_text()

PIEFED_OPERATIONS = {
    "getSite": {
        "enum": "GetSite",
        "signal": "getSiteFinished",
        "handler": "onGetSiteFinished",
        "endpoint": "/api/alpha/site",
    },
    "listPosts": {
        "enum": "ListPosts",
        "signal": "listPostsFinished",
        "handler": "onListPostsFinished",
        "endpoint": "/api/alpha/post/list",
    },
    "listComments": {
        "enum": "ListComments",
        "signal": "listCommentsFinished",
        "handler": "onListCommentsFinished",
        "endpoint": "/api/alpha/comment/list",
    },
    "getPost": {
        "enum": "GetPost",
        "signal": "getPostFinished",
        "handler": "onGetPostFinished",
        "endpoint": "/api/alpha/post",
    },
    "likePost": {
        "enum": "LikePost",
        "signal": "likePostFinished",
        "handler": "onLikePostFinished",
        "endpoint": "/api/alpha/post/like",
    },
    "likeComment": {
        "enum": "LikeComment",
        "signal": "likeCommentFinished",
        "handler": "onLikeCommentFinished",
        "endpoint": "/api/alpha/comment/like",
    },
    "createComment": {
        "enum": "CreateComment",
        "signal": "createCommentFinished",
        "handler": "onCreateCommentFinished",
        "endpoint": "/api/alpha/comment",
    },
    "listCommunities": {
        "enum": "ListCommunities",
        "signal": "listCommunitiesFinished",
        "handler": "onListCommunitiesFinished",
        "endpoint": "/api/alpha/community/list",
    },
    "getCommunity": {
        "enum": "GetCommunity",
        "signal": "getCommunityFinished",
        "handler": "onGetCommunityFinished",
        "endpoint": "/api/alpha/community",
    },
    "getPerson": {
        "enum": "GetPerson",
        "signal": "getPersonFinished",
        "handler": "onGetPersonFinished",
        "endpoint": "/api/alpha/user",
    },
    "search": {
        "enum": "Search",
        "signal": "searchFinished",
        "handler": "onSearchFinished",
        "endpoint": "/api/alpha/search",
    },
    "followCommunity": {
        "enum": "FollowCommunity",
        "signal": "followCommunityFinished",
        "handler": "onFollowCommunityFinished",
        "endpoint": "/api/alpha/community/follow",
    },
}

LEMMYAPI_PIEFED_HELPERS = {
    "listPosts": "routeListPosts",
    "loadMorePosts": "routeListPosts",
}

LEMMYAPI_PIEFED_ROUTES = {
    "routeListPosts": "listPosts",
    "loadMoreComments": "listComments",
    "listComments": "listComments",
    "getSite": "getSite",
    "loadMoreCommunities": "listCommunities",
    "likeComment": "likeComment",
    "createComment": "createComment",
    "listCommunities": "listCommunities",
    "getPost": "getPost",
    "likePost": "likePost",
    "getCommunity": "getCommunity",
    "getPerson": "getPerson",
    "search": "search",
    "followCommunity": "followCommunity",
}


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
                return source[brace + 1:index]
    raise AssertionError(f"unterminated function body for {signature}")


def assert_contains_all(text: str, expected: list[str], context: str) -> None:
    missing = [token for token in expected if token not in text]
    assert not missing, f"{context} missing {missing}"


def test_lemmyapi_piefed_mode_routes_operations_to_piefedclient() -> None:
    assert "TODO(EVO-010)" not in LEMMY_API_CPP
    assert "finishUnsupportedPieFedOperation" not in LEMMY_API_CPP
    assert "finishUnsupportedPieFedOperation" not in LEMMY_API_H

    for lemmyapi_function, helper in LEMMYAPI_PIEFED_HELPERS.items():
        body = extract_function_body(
            LEMMY_API_CPP, f"void LemmyAPI::{lemmyapi_function}"
        )
        assert f"{helper}(" in body
        assert "QMetaObject::invokeMethod" not in body

    for lemmyapi_function, client_method in LEMMYAPI_PIEFED_ROUTES.items():
        body = extract_function_body(
            LEMMY_API_CPP, f"void LemmyAPI::{lemmyapi_function}"
        )
        call = f"m_piefedClient->{client_method}("
        assert "m_serverKind == ServerKind::PieFed" in body
        assert call in body

        return_index = body.find("return;", body.find(call))
        worker_index = body.find("QMetaObject::invokeMethod", body.find(call))
        assert return_index >= 0
        if worker_index >= 0:
            assert return_index < worker_index


def test_piefedclient_exposes_and_emits_matching_operations() -> None:
    emit_body = extract_function_body(
        PIEFED_CLIENT_CPP, "void PieFedClient::emitFinished"
    )
    enum_body = PIEFED_CLIENT_H.split("enum class Operation {", 1)[1].split(
        "};", 1
    )[0]

    for method, contract in PIEFED_OPERATIONS.items():
        body = extract_function_body(
            PIEFED_CLIENT_CPP, f"void PieFedClient::{method}"
        )
        assert f"void {method}(" in PIEFED_CLIENT_H
        assert contract["endpoint"] in body
        assert f"Operation::{contract['enum']}" in body
        assert contract["enum"] in enum_body

        signal = contract["signal"]
        assert f"void {signal}(const QString &json);" in PIEFED_CLIENT_H
        assert f"case Operation::{contract['enum']}:" in emit_body
        assert f"emit {signal}(json);" in emit_body

        assert f"&PieFedClient::{signal}" in LEMMY_API_CPP
        assert f"&LemmyAPI::{contract['handler']}" in LEMMY_API_CPP


def test_representative_piefed_normalization_keeps_qml_consumed_fields() -> None:
    assert_contains_all(
        extract_function_body(
            PIEFED_CLIENT_CPP, "QJsonObject PieFedClient::normalizePostView"
        ),
        [
            "title",
            "name",
            "user_id",
            "creator_id",
            "sticky",
            "featured_community",
            "instance_sticky",
            "featured_local",
            "normalizePersonView",
            "normalizeCommunityView",
        ],
        "post view normalization",
    )
    assert_contains_all(
        extract_function_body(
            PIEFED_CLIENT_CPP, "QJsonObject PieFedClient::normalizeCommentView"
        ),
        ["body", "content", "user_id", "creator_id"],
        "comment view normalization",
    )
    assert_contains_all(
        extract_function_body(
            PIEFED_CLIENT_CPP, "QJsonObject PieFedClient::normalizeCommunityView"
        ),
        [
            "subscriptions_count",
            "subscribers",
            "post_count",
            "posts",
            "post_reply_count",
            "comments",
        ],
        "community view normalization",
    )
    assert_contains_all(
        extract_function_body(
            PIEFED_CLIENT_CPP, "QJsonObject PieFedClient::normalizeSite"
        ),
        [
            "admins",
            "normalizePersonView",
            "site",
            "site_view",
            "user_count",
            "users",
        ],
        "site normalization",
    )
    assert_contains_all(
        extract_function_body(
            PIEFED_CLIENT_CPP, "QJsonObject PieFedClient::normalizePersonView"
        ),
        ["user_name", "name"],
        "person view normalization",
    )
