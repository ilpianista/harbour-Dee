"""EVO-030 checks for PieFed cursor pagination and post sort choices."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEMMY_API_CPP = (ROOT / "src" / "lemmyapi.cpp").read_text()
LEMMY_API_H = (ROOT / "src" / "lemmyapi.h").read_text()
PIEFED_CLIENT_CPP = (ROOT / "src" / "piefedclient.cpp").read_text()
DEE_QML = (ROOT / "qml" / "Dee.qml").read_text()
SUBSCRIBED_QML = (ROOT / "qml" / "pages" / "SubscribedPage.qml").read_text()


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
    assert start >= 0, f"missing function {signature}"
    brace = source.find("{", start)
    assert brace >= 0, f"missing function body for {signature}"
    return source[brace + 1 : matching_index(source, brace)]


def extract_piefed_branch(body: str) -> str:
    condition = "m_serverKind == ServerKind::PieFed"
    condition_index = body.find(condition)
    assert condition_index >= 0, "missing PieFed branch"
    if_index = body.rfind("if", 0, condition_index)
    assert if_index >= 0, "missing if for PieFed branch"
    condition_open = body.find("(", if_index)
    condition_close = matching_index(body, condition_open, "(", ")")
    branch_open = body.find("{", condition_close)
    assert branch_open >= 0, "missing PieFed branch block"
    return body[branch_open + 1 : matching_index(body, branch_open)]


def qml_array_body(source: str, property_name: str) -> str:
    start = source.find(f"readonly property var {property_name}: [")
    assert start >= 0, f"missing QML array {property_name}"
    open_index = source.find("[", start)
    return source[open_index + 1 : matching_index(source, open_index, "[", "]")]


def assert_ordered(text: str, *needles: str) -> None:
    position = -1
    for needle in needles:
        next_position = text.find(needle, position + 1)
        assert next_position >= 0, f"missing {needle!r} after offset {position}"
        position = next_position


def test_evo030_marker_is_removed_after_gap_is_closed() -> None:
    assert "TODO(EVO-030)" not in PIEFED_CLIENT_CPP
    assert "TODO(EVO-030)" not in LEMMY_API_CPP
    assert "TODO(EVO-030)" not in DEE_QML


def test_piefed_load_more_uses_next_page_metadata_without_lemmy_page_increment() -> None:
    cases = {
        "Posts": ("loadMorePosts", "m_piefedPostsNextPage", "m_postsPage++"),
        "Communities": (
            "loadMoreCommunities",
            "m_piefedCommunitiesNextPage",
            "m_communitiesPage++",
        ),
        "Comments": (
            "loadMoreComments",
            "m_piefedCommentsNextPage",
            "m_commentsPage++",
        ),
    }

    for _, (function, next_page_member, lemmy_increment) in cases.items():
        body = extract_function_body(LEMMY_API_CPP, f"void LemmyAPI::{function}")
        piefed_branch = extract_piefed_branch(body)
        lemmy_branch = body[body.find(piefed_branch) + len(piefed_branch) :]

        assert_ordered(
            piefed_branch,
            f"{next_page_member}.isUndefined()",
            "return;",
            "setBusy(true);",
            "params[QStringLiteral(\"page\")] = " + next_page_member,
        )
        assert lemmy_increment not in piefed_branch
        assert lemmy_increment in lemmy_branch


def test_piefed_list_handlers_store_next_page_from_successful_responses() -> None:
    for handler, next_page_member in {
        "onListPostsFinished": "m_piefedPostsNextPage",
        "onListCommunitiesFinished": "m_piefedCommunitiesNextPage",
        "onListCommentsFinished": "m_piefedCommentsNextPage",
    }.items():
        body = extract_function_body(LEMMY_API_CPP, f"void LemmyAPI::{handler}")
        assert_ordered(
            body,
            "if (obj.contains(QStringLiteral(\"error\")))",
            "return;",
            "if (m_serverKind == ServerKind::PieFed)",
            f"{next_page_member} = obj.value(QStringLiteral(\"next_page\"));",
        )

    for member in (
        "m_piefedPostsNextPage",
        "m_piefedCommunitiesNextPage",
        "m_piefedCommentsNextPage",
    ):
        assert f"QJsonValue {member};" in LEMMY_API_H


def test_piefed_post_sort_picker_excludes_lemmy_only_aliases_without_changing_lemmy_options() -> None:
    lemmy_options = qml_array_body(DEE_QML, "sortOptions")
    piefed_options = qml_array_body(DEE_QML, "pieFedSortOptions")

    for value in ("Controversial", "MostComments", "NewComments"):
        assert f'"value": "{value}"' in lemmy_options
        assert f'"value": "{value}"' not in piefed_options

    for value in ("Hot", "Active", "New", "TopDay", "TopWeek", "TopMonth", "TopYear", "TopAll"):
        assert f'"value": "{value}"' in piefed_options

    assert "return serverKind === \"piefed\" ? pieFedSortOptions : sortOptions;" in DEE_QML
    assert '"options": appWindow.postSortOptions(api.serverKind)' in SUBSCRIBED_QML
    assert "appWindow.sortLabel(appWindow.currentSort, api.serverKind)" in SUBSCRIBED_QML
    assert "appWindow.postSortForServer(api.currentSort, api.serverKind)" in SUBSCRIBED_QML
