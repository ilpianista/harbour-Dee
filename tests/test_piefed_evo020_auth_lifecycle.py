"""Static EVO-020 checks for PieFed auth lifecycle hardening.

The repository cannot run Qt objects in tests here, so these tests trace the
real C++ data flow across the production functions that own the lifecycle.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEMMY_API_CPP = (ROOT / "src" / "lemmyapi.cpp").read_text()
LEMMY_API_H = (ROOT / "src" / "lemmyapi.h").read_text()
PIEFED_CLIENT_CPP = (ROOT / "src" / "piefedclient.cpp").read_text()
PIEFED_CLIENT_H = (ROOT / "src" / "piefedclient.h").read_text()

REQUEST_HANDLERS = {
    "onGetSiteFinished": "getSite",
    "onListPostsFinished": "listPosts",
    "onGetPostFinished": "getPost",
    "onLikePostFinished": "likePost",
    "onListCommentsFinished": "listComments",
    "onLikeCommentFinished": "likeComment",
    "onCreateCommentFinished": "createComment",
    "onListCommunitiesFinished": "listCommunities",
    "onGetCommunityFinished": "getCommunity",
    "onGetPersonFinished": "getPerson",
    "onSearchFinished": "search",
    "onFollowCommunityFinished": "followCommunity",
}


def matching_index(text: str, open_index: int, opener: str = "{", closer: str = "}") -> int:
    depth = 0
    for index in range(open_index, len(text)):
        if text[index] == opener:
            depth += 1
        elif text[index] == closer:
            depth -= 1
            if depth == 0:
                return index
    raise AssertionError(f"unterminated block starting at {open_index}")


def extract_function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    while start >= 0:
        brace = source.find("{", start)
        semicolon = source.find(";", start)
        if brace >= 0 and (semicolon < 0 or brace < semicolon):
            break
        start = source.find(signature, start + len(signature))
    assert start >= 0, f"missing function {signature}"
    brace = source.find("{", start)
    assert brace >= 0, f"missing function body for {signature}"
    return source[brace + 1 : matching_index(source, brace)]


def extract_if_body_with_bounds(body: str, condition_fragment: str) -> tuple[str, int, int]:
    condition_index = body.find(condition_fragment)
    assert condition_index >= 0, f"missing condition fragment {condition_fragment!r}"

    if_index = body.rfind("if", 0, condition_index)
    assert if_index >= 0, f"missing if for {condition_fragment!r}"
    condition_open = body.find("(", if_index)
    assert condition_open >= 0, f"missing condition for {condition_fragment!r}"
    condition_close = matching_index(body, condition_open, "(", ")")

    statement_start = condition_close + 1
    while statement_start < len(body) and body[statement_start].isspace():
        statement_start += 1

    if statement_start < len(body) and body[statement_start] == "{":
        statement_end = matching_index(body, statement_start)
        return body[statement_start + 1 : statement_end], if_index, statement_end

    statement_end = body.find(";", statement_start)
    assert statement_end >= 0, f"missing statement body for {condition_fragment!r}"
    return body[statement_start : statement_end + 1], if_index, statement_end


def extract_if_body(body: str, condition_fragment: str) -> str:
    if_body, _, _ = extract_if_body_with_bounds(body, condition_fragment)
    return if_body


def extract_if_else(body: str, condition_fragment: str) -> tuple[str, str]:
    if_body, _, if_close = extract_if_body_with_bounds(body, condition_fragment)

    remainder = body[if_close + 1 :]
    else_index = remainder.find("else")
    assert else_index >= 0, f"missing else for {condition_fragment!r}"
    else_open = remainder.find("{", else_index)
    assert else_open >= 0, f"missing else block for {condition_fragment!r}"
    else_close = matching_index(remainder, else_open)
    return if_body, remainder[else_open + 1 : else_close]


def extract_call_args(body: str, call: str, start: int = 0) -> tuple[list[str], int, int]:
    call_index = body.find(call, start)
    assert call_index >= 0, f"missing call {call!r}"
    open_index = body.find("(", call_index + len(call) - 1)
    assert open_index >= 0, f"missing argument list for {call!r}"
    close_index = matching_index(body, open_index, "(", ")")
    return split_top_level_args(body[open_index + 1 : close_index]), call_index, close_index


def split_top_level_args(args: str) -> list[str]:
    result: list[str] = []
    depth = 0
    start = 0
    pairs = {"(": ")", "[": "]", "{": "}"}
    closing = {value: key for key, value in pairs.items()}
    stack: list[str] = []
    for index, char in enumerate(args):
        if char in pairs:
            stack.append(char)
            depth += 1
        elif char in closing and stack and stack[-1] == closing[char]:
            stack.pop()
            depth -= 1
        elif char == "," and depth == 0:
            result.append(args[start:index].strip())
            start = index + 1
    result.append(args[start:].strip())
    return result


def assert_ordered(text: str, *needles: str) -> None:
    position = -1
    for needle in needles:
        next_position = text.find(needle, position + 1)
        assert next_position >= 0, f"missing {needle!r} after offset {position}"
        position = next_position


def assert_clears_token_scope(body: str) -> None:
    assert "m_jwt.clear();" in body
    assert "m_secureStorage->clearAll();" in body
    assert 'm_settings->remove(QStringLiteral("accessTokenInstanceUrl"));' in body
    assert 'm_settings->remove(QStringLiteral("accessTokenServerKind"));' in body


def assert_clears_pending_piefed_login(body: str) -> None:
    assert "setLoggedIn(false);" in body
    assert_clears_token_scope(body)
    assert 'm_settings->remove(QStringLiteral("username"));' in body
    assert 'm_settings->remove(QStringLiteral("instanceUrl"));' in body
    assert 'm_settings->remove(QStringLiteral("serverKind"));' in body
    assert "m_piefedClient->setJwt(QString());" in body
    assert "m_username.clear();" in body
    assert "m_instanceUrl.clear();" in body
    assert "emit usernameChanged();" in body
    assert "emit instanceUrlChanged();" in body


def test_piefed_login_sends_totp_in_the_json_body_used_for_login_post() -> None:
    assert "TODO(EVO-020)" not in LEMMY_API_CPP
    assert "void login(const QString &username, const QString &password," in PIEFED_CLIENT_H
    assert "const QString &totp);" in PIEFED_CLIENT_H

    client_login = extract_function_body(PIEFED_CLIENT_CPP, "void PieFedClient::login")
    post_args, post_index, _ = extract_call_args(client_login, "post")
    assert post_args == [
        "Operation::Login",
        'QStringLiteral("/api/alpha/user/login")',
        "body",
        "nullptr",
    ]

    assert_ordered(
        client_login,
        'body[QStringLiteral("username")] = username;',
        'body[QStringLiteral("password")] = password;',
        "if (!totp.isEmpty())",
        'body[QStringLiteral("totp_2fa_token")] = totp;',
        "post(Operation::Login",
    )
    assert client_login.find('body[QStringLiteral("totp_2fa_token")] = totp;') < post_index

    api_login = extract_function_body(LEMMY_API_CPP, "void LemmyAPI::login")
    piefed_branch, _, piefed_end = extract_if_body_with_bounds(
        api_login, "m_serverKind == ServerKind::PieFed"
    )
    assert "m_piefedClient->login(username, password, totp);" in piefed_branch
    assert "m_piefedClient->login(username, password);" not in api_login
    assert "return;" in piefed_branch
    assert "Q_ARG(QString, totp)" in api_login[piefed_end + 1 :]


def test_piefed_logout_is_local_cleanup_without_unsupported_server_route() -> None:
    assert "void logout();" not in PIEFED_CLIENT_H
    assert "PieFedClient::logout" not in PIEFED_CLIENT_CPP
    assert "/api/alpha/user/logout" not in PIEFED_CLIENT_CPP
    assert "m_piefedClient->logout" not in LEMMY_API_CPP

    api_logout = extract_function_body(LEMMY_API_CPP, "void LemmyAPI::logout")
    piefed_branch, _, piefed_end = extract_if_body_with_bounds(
        api_logout, "m_serverKind == ServerKind::PieFed"
    )
    lemmy_branch = api_logout[piefed_end + 1 :]
    assert_ordered(
        piefed_branch,
        "clearLocalSession();",
        "setBusy(false);",
        "return;",
    )
    assert "QMetaObject::invokeMethod" not in piefed_branch
    assert "QMetaObject::invokeMethod(m_worker, \"doLogout\"" in lemmy_branch

    clear_session = extract_function_body(LEMMY_API_CPP, "void LemmyAPI::clearLocalSession")
    assert_ordered(
        clear_session,
        "setLoggedIn(false);",
        "m_jwt.clear();",
        "m_piefedClient->cancelPendingRequests();",
        "m_piefedClient->setJwt(QString());",
        'm_settings->remove(QStringLiteral("accessTokenInstanceUrl"));',
        'm_settings->remove(QStringLiteral("accessTokenServerKind"));',
    )


def test_piefed_auth_errors_flow_from_network_reply_to_session_cleanup() -> None:
    assert "void finishRequestError" in LEMMY_API_H

    finish_json = extract_function_body(PIEFED_CLIENT_CPP, "static QString finishJson")
    assert_ordered(
        finish_json,
        "const int status =",
        "QNetworkRequest::HttpStatusCodeAttribute",
        "if (reply->error() != QNetworkReply::NoError || status >= 400)",
        "return errorJson(responseErrorText(reply, obj), status);",
    )

    error_json = extract_function_body(PIEFED_CLIENT_CPP, "static QString errorJson")
    status_body = extract_if_body(error_json, "status > 0")
    assert 'obj[QStringLiteral("status_code")] = status;' in status_body

    response_error = extract_function_body(
        PIEFED_CLIENT_CPP, "static QString responseErrorText"
    )
    assert_ordered(
        response_error,
        'obj.value(QStringLiteral("error")).toString();',
        "return error;",
        'obj.value(QStringLiteral("message")).toString();',
        'obj.value(QStringLiteral("status")).toString();',
    )

    finish_error = extract_function_body(LEMMY_API_CPP, "void LemmyAPI::finishRequestError")
    assert "m_serverKind == ServerKind::PieFed" in finish_error
    assert_ordered(
        finish_error,
        'setError(obj[QStringLiteral("error")].toString());',
        'const int status = obj.value(QStringLiteral("status_code")).toInt();',
        "const QString normalizedError = m_error.trimmed();",
        "const bool pieFedAuthFailure =",
        "status == 401",
        "status == 400",
        'normalizedError.startsWith(QStringLiteral("incorrect_login"))',
        'normalizedError == QStringLiteral("not_logged_in")',
        "if (pieFedAuthFailure)",
        "clearLocalSession();",
        "setBusy(false);",
        "emit requestFailed(method, m_error);",
    )

    for handler, method in REQUEST_HANDLERS.items():
        body = extract_function_body(LEMMY_API_CPP, f"void LemmyAPI::{handler}")
        error_body = extract_if_body(body, 'obj.contains(QStringLiteral("error"))')
        assert f'finishRequestError(QStringLiteral("{method}"), obj);' in error_body
        assert "return;" in error_body


def test_stored_token_scope_gates_startup_login_and_clears_stale_tokens() -> None:
    constructor = extract_function_body(LEMMY_API_CPP, "LemmyAPI::LemmyAPI")
    token_present, missing_instance = extract_if_else(
        constructor, "!m_jwt.isEmpty() && !m_instanceUrl.isEmpty()"
    )
    valid_scope, stale_scope = extract_if_else(
        token_present, "tokenInstanceUrl == m_instanceUrl"
    )

    assert_ordered(
        token_present,
        'm_settings->value(QStringLiteral("accessTokenInstanceUrl")).toString();',
        'm_settings->value(QStringLiteral("accessTokenServerKind")).toString();',
        "const bool tokenHasScope =",
        "tokenInstanceUrl == m_instanceUrl",
        "tokenServerKind == serverKind()",
    )
    assert constructor.count("m_loggedIn = true;") == 1
    assert "m_loggedIn = true;" in valid_scope
    assert "m_loggedIn = true;" not in stale_scope
    assert "m_loggedIn = true;" not in missing_instance
    assert_clears_token_scope(stale_scope)
    assert_clears_token_scope(missing_instance)

    login_finished = extract_function_body(LEMMY_API_CPP, "void LemmyAPI::onLoginFinished")
    assert_ordered(
        login_finished,
        "m_secureStorage->saveAccessToken(jwt);",
        'm_settings->setValue(QStringLiteral("accessTokenInstanceUrl"),',
        'm_settings->setValue(QStringLiteral("accessTokenServerKind"),',
        "setLoggedIn(true);",
    )

    login_error = extract_if_body(login_finished, 'obj.contains(QStringLiteral("error"))')
    assert_clears_pending_piefed_login(
        extract_if_body(login_error, "m_serverKind == ServerKind::PieFed")
    )
    _, no_token = extract_if_else(login_finished, "!jwt.isEmpty()")
    assert_clears_pending_piefed_login(
        extract_if_body(no_token, "m_serverKind == ServerKind::PieFed")
    )

    clear_session = extract_function_body(LEMMY_API_CPP, "void LemmyAPI::clearLocalSession")
    assert_clears_token_scope(clear_session)
    assert "m_piefedClient->cancelPendingRequests();" in clear_session
    for key in ("username", "instanceUrl", "serverKind"):
        assert f'm_settings->remove(QStringLiteral("{key}"));' in clear_session
