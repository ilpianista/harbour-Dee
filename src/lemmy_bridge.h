#ifndef LEMMY_BRIDGE_H
#define LEMMY_BRIDGE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Opaque handle exposed to C.
 */
typedef struct LemmyClientHandle LemmyClientHandle;

/**
 * Create a new Lemmy client for the given instance domain.
 *
 * `domain` – e.g. `"lemmy.world"` (without scheme).
 * `secure` – whether to use HTTPS.
 *
 * Returns an opaque handle. The caller must eventually call
 * `lemmy_client_free`.
 */
struct LemmyClientHandle *lemmy_client_new(const char *domain, bool secure);

/**
 * Destroy a Lemmy client handle previously returned by `lemmy_client_new`.
 */
void lemmy_client_free(struct LemmyClientHandle *handle);

/**
 * Set the JWT authorization header on the client.
 * Pass `NULL` or empty string to clear it.
 */
void lemmy_client_set_jwt(struct LemmyClientHandle *handle, const char *jwt);

/**
 * Free a C string previously returned by any `lemmy_*` function.
 */
void lemmy_free_string(char *s);

/**
 * Log in. Returns JSON `{"jwt":"..."}` on success or `{"error":"..."}` on
 * failure.
 */
char *lemmy_login(struct LemmyClientHandle *handle,
                  const char *username_or_email, const char *password,
                  const char *totp_token);

/**
 * Log out (invalidates the JWT on the server). Returns JSON.
 */
char *lemmy_logout(struct LemmyClientHandle *handle);

/**
 * Get site info. Returns JSON.
 */
char *lemmy_get_site(struct LemmyClientHandle *handle);

/**
 * List posts. `json_params` is a JSON-serialised `GetPosts` struct.
 * Returns JSON `GetPostsResponse`.
 */
char *lemmy_list_posts(struct LemmyClientHandle *handle,
                       const char *json_params);

/**
 * Get a single post. `json_params` is a JSON-serialised `GetPost`.
 */
char *lemmy_get_post(struct LemmyClientHandle *handle, const char *json_params);

/**
 * Vote on a post. `json_params` is a JSON-serialised `CreatePostLike`.
 */
char *lemmy_like_post(struct LemmyClientHandle *handle,
                      const char *json_params);

/**
 * List comments. `json_params` is a JSON-serialised `GetComments`.
 */
char *lemmy_list_comments(struct LemmyClientHandle *handle,
                          const char *json_params);

/**
 * List communities. `json_params` is a JSON-serialised `ListCommunities`.
 */
char *lemmy_list_communities(struct LemmyClientHandle *handle,
                             const char *json_params);

/**
 * Get a single community. `json_params` is a JSON-serialised `GetCommunity`.
 */
char *lemmy_get_community(struct LemmyClientHandle *handle,
                          const char *json_params);

/**
 * Get person details. `json_params` is a JSON-serialised `GetPersonDetails`.
 */
char *lemmy_get_person(struct LemmyClientHandle *handle,
                       const char *json_params);

/**
 * Search. `json_params` is a JSON-serialised `Search`.
 */
char *lemmy_search(struct LemmyClientHandle *handle, const char *json_params);

/**
 * Follow/unfollow a community. `json_params` is a JSON-serialised object with
 * `community_id` (i64) and `follow` (bool).
 */
char *lemmy_follow_community(struct LemmyClientHandle *handle,
                             const char *json_params);

#ifdef __cplusplus
}
#endif

#endif /* LEMMY_BRIDGE_H */
