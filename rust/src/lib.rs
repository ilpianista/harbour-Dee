//! C FFI bridge for lemmy-client-rs.
//!
//! Provides blocking C-compatible functions that internally run async
//! lemmy-client calls on a tokio runtime. Returns JSON strings that the
//! C++ side can parse with Qt's QJsonDocument.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::sync::OnceLock;

use lemmy_client::lemmy_api_common::{
    comment::{CreateComment, CreateCommentLike, GetComments},
    community::{FollowCommunity, GetCommunity, ListCommunities},
    person::{GetPersonDetails, Login},
    post::{CreatePostLike, GetPost, GetPosts},
    site::Search,
};
use lemmy_client::{ClientOptions, LemmyClient};
use serde_json;
use tokio::runtime::Runtime;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Global tokio runtime shared by all FFI calls.
fn runtime() -> &'static Runtime {
    static RT: OnceLock<Runtime> = OnceLock::new();
    RT.get_or_init(|| Runtime::new().expect("failed to create tokio runtime"))
}

/// Opaque handle exposed to C.
pub struct LemmyClientHandle {
    client: LemmyClient,
}

/// Turn a `*const c_char` into a `&str`. Returns `None` on null / invalid UTF-8.
unsafe fn cstr_to_str<'a>(p: *const c_char) -> Option<&'a str> {
    if p.is_null() {
        return None;
    }
    CStr::from_ptr(p).to_str().ok()
}

/// Allocate a C string on the heap. Caller must free with `lemmy_free_string`.
fn to_c_string(s: &str) -> *mut c_char {
    match CString::new(s) {
        Ok(cs) => cs.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

/// Serialise any `serde::Serialize` value to a heap-allocated C string.
fn json_to_c<T: serde::Serialize>(val: &T) -> *mut c_char {
    match serde_json::to_string(val) {
        Ok(s) => to_c_string(&s),
        Err(e) => to_c_string(&format!(r#"{{"error":"{}"}}"#, e)),
    }
}

/// Wrap a LemmyResult into a C string. On error returns `{"error":"..."}`.
fn result_to_c<T: serde::Serialize>(
    res: Result<T, lemmy_client::lemmy_api_common::LemmyErrorType>,
) -> *mut c_char {
    match res {
        Ok(val) => json_to_c(&val),
        Err(e) => to_c_string(&format!(r#"{{"error":"{}"}}"#, e)),
    }
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// Create a new Lemmy client for the given instance domain.
///
/// `domain` – e.g. `"lemmy.world"` (without scheme).
/// `secure` – whether to use HTTPS.
///
/// Returns an opaque handle. The caller must eventually call `lemmy_client_free`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_client_new(
    domain: *const c_char,
    secure: bool,
) -> *mut LemmyClientHandle {
    let domain_str = match cstr_to_str(domain) {
        Some(s) => s,
        None => return ptr::null_mut(),
    };
    let client = LemmyClient::new(ClientOptions {
        domain: domain_str.to_owned(),
        secure,
    });
    Box::into_raw(Box::new(LemmyClientHandle { client }))
}

/// Destroy a Lemmy client handle previously returned by `lemmy_client_new`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_client_free(handle: *mut LemmyClientHandle) {
    if !handle.is_null() {
        drop(Box::from_raw(handle));
    }
}

/// Set the JWT authorization header on the client.
/// Pass `NULL` or empty string to clear it.
#[no_mangle]
pub unsafe extern "C" fn lemmy_client_set_jwt(handle: *mut LemmyClientHandle, jwt: *const c_char) {
    if handle.is_null() {
        return;
    }
    let h = &mut *handle;
    let headers = h.client.headers_mut();
    match cstr_to_str(jwt) {
        Some(token) if !token.is_empty() => {
            headers.insert("Authorization".to_owned(), format!("Bearer {}", token));
        }
        _ => {
            headers.remove("Authorization");
        }
    }
}

/// Free a C string previously returned by any `lemmy_*` function.
#[no_mangle]
pub unsafe extern "C" fn lemmy_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

/// Log in. Returns JSON `{"jwt":"..."}` on success or `{"error":"..."}` on failure.
#[no_mangle]
pub unsafe extern "C" fn lemmy_login(
    handle: *mut LemmyClientHandle,
    username_or_email: *const c_char,
    password: *const c_char,
    totp_token: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let uname = match cstr_to_str(username_or_email) {
        Some(s) => s.to_owned(),
        None => return to_c_string(r#"{"error":"invalid username"}"#),
    };
    let pass = match cstr_to_str(password) {
        Some(s) => s.to_owned(),
        None => return to_c_string(r#"{"error":"invalid password"}"#),
    };
    let totp = cstr_to_str(totp_token)
        .filter(|s| !s.is_empty())
        .map(|s| s.to_owned());

    let form = Login {
        username_or_email: uname.into(),
        password: pass.into(),
        totp_2fa_token: totp,
    };

    let res = runtime().block_on(h.client.login(form));
    result_to_c(res)
}

/// Log out (invalidates the JWT on the server). Returns JSON.
#[no_mangle]
pub unsafe extern "C" fn lemmy_logout(handle: *mut LemmyClientHandle) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let res = runtime().block_on(h.client.logout(()));
    result_to_c(res)
}

// ---------------------------------------------------------------------------
// Site
// ---------------------------------------------------------------------------

/// Get site info. Returns JSON.
#[no_mangle]
pub unsafe extern "C" fn lemmy_get_site(handle: *mut LemmyClientHandle) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let res = runtime().block_on(h.client.get_site(()));
    result_to_c(res)
}

// ---------------------------------------------------------------------------
// Posts
// ---------------------------------------------------------------------------

/// List posts. `json_params` is a JSON-serialised `GetPosts` struct.
/// Returns JSON `GetPostsResponse`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_list_posts(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: GetPosts = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => GetPosts::default(),
    };
    let res = runtime().block_on(h.client.list_posts(params));
    result_to_c(res)
}

/// Get a single post. `json_params` is a JSON-serialised `GetPost`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_get_post(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: GetPost = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => return to_c_string(r#"{"error":"params required"}"#),
    };
    let res = runtime().block_on(h.client.get_post(params));
    result_to_c(res)
}

/// Vote on a post. `json_params` is a JSON-serialised `CreatePostLike`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_like_post(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: CreatePostLike = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => return to_c_string(r#"{"error":"params required"}"#),
    };
    let res = runtime().block_on(h.client.like_post(params));
    result_to_c(res)
}

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

/// List comments. `json_params` is a JSON-serialised `GetComments`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_list_comments(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: GetComments = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => GetComments::default(),
    };
    let res = runtime().block_on(h.client.list_comments(params));
    result_to_c(res)
}

/// Vote on a comment. `json_params` is a JSON-serialised `CreateCommentLike`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_like_comment(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: CreateCommentLike = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => return to_c_string(r#"{"error":"params required"}"#),
    };
    let res = runtime().block_on(h.client.like_comment(params));
    result_to_c(res)
}

/// Create a comment. `json_params` is a JSON-serialised `CreateComment`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_create_comment(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: CreateComment = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => return to_c_string(r#"{"error":"params required"}"#),
    };
    let res = runtime().block_on(h.client.create_comment(params));
    result_to_c(res)
}

// ---------------------------------------------------------------------------
// Communities
// ---------------------------------------------------------------------------

/// List communities. `json_params` is a JSON-serialised `ListCommunities`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_list_communities(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: ListCommunities = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => ListCommunities::default(),
    };
    let res = runtime().block_on(h.client.list_communities(params));
    result_to_c(res)
}

/// Get a single community. `json_params` is a JSON-serialised `GetCommunity`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_get_community(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: GetCommunity = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => return to_c_string(r#"{"error":"params required"}"#),
    };
    let res = runtime().block_on(h.client.get_community(params));
    result_to_c(res)
}

// ---------------------------------------------------------------------------
// User
// ---------------------------------------------------------------------------

/// Get person details. `json_params` is a JSON-serialised `GetPersonDetails`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_get_person(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: GetPersonDetails = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => GetPersonDetails::default(),
    };
    let res = runtime().block_on(h.client.get_person(params));
    result_to_c(res)
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

/// Search. `json_params` is a JSON-serialised `Search`.
#[no_mangle]
pub unsafe extern "C" fn lemmy_search(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: Search = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => return to_c_string(r#"{"error":"params required"}"#),
    };
    let res = runtime().block_on(h.client.search(params));
    result_to_c(res)
}

/// Follow/unfollow a community. `json_params` is a JSON-serialised object with
/// `community_id` (i64) and `follow` (bool).
#[no_mangle]
pub unsafe extern "C" fn lemmy_follow_community(
    handle: *mut LemmyClientHandle,
    json_params: *const c_char,
) -> *mut c_char {
    if handle.is_null() {
        return to_c_string(r#"{"error":"null handle"}"#);
    }
    let h = &*handle;
    let params: FollowCommunity = match cstr_to_str(json_params) {
        Some(s) => match serde_json::from_str(s) {
            Ok(p) => p,
            Err(e) => return to_c_string(&format!(r#"{{"error":"bad params: {}"}}"#, e)),
        },
        None => return to_c_string(r#"{"error":"params required"}"#),
    };
    let res = runtime().block_on(h.client.follow_community(params));
    result_to_c(res)
}
