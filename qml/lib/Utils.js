.pragma library

function escapeHtml(text) {
    return String(text)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function linkify(text, linkColor) {
    if (!text)
        return "";

    var escaped = escapeHtml(text);
    var pattern = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|&lt;(https?:\/\/[^\s&]+)&gt;|(https?:\/\/[^\s<)]+)/g;
    var linked = false;

    var result = escaped.replace(pattern, function (match, markdownLabel, markdownUrl, autolinkUrl, bareUrl) {
        linked = true;

        if (markdownUrl)
            return '<a href="' + markdownUrl + '">' + markdownLabel + '</a>';

        if (autolinkUrl)
            return '<a href="' + autolinkUrl + '">' + autolinkUrl + '</a>';

        var url = bareUrl;
        var trailing = "";
        var trailingMatch = url.match(/[.,;:!?]+$/);
        if (trailingMatch) {
            trailing = trailingMatch[0];
            url = url.substring(0, url.length - trailing.length);
        }
        return '<a href="' + url + '">' + url + '</a>' + trailing;
    }).replace(/\n/g, "<br>");

    if (linked && linkColor)
        result = '<style>a:link{color:' + linkColor + ';}</style>' + result;

    return result;
}

function resolveHandle(actorId, prefixChar) {
    if (!actorId)
        return "";
    var parts = actorId.split("/" + prefixChar + "/");
    if (parts.length < 2)
        return actorId;
    var name = parts[1];
    var urlParts = actorId.split("://");
    var domain = urlParts.length >= 2 ? urlParts[1].split("/")[0] : "";
    return domain ? name + "@" + domain : name;
}

function formatAuthor(actorId) {
    return resolveHandle(actorId, "u");
}

function resolveCommunityHandle(actorId) {
    return resolveHandle(actorId, "c");
}

function applyPostViewResult(result, page, appWindow, api) {
    var pv = result.post_view;
    page.postMyVote = pv.my_vote ? pv.my_vote : 0;
    page.postComments = pv.counts.comments;
    page.postScore = pv.counts.score;
    page.postTitle = pv.post.name;
    appWindow.postTitle = page.postTitle;
    appWindow.postScore = page.postScore;
    appWindow.postComments = page.postComments;
    if (api && pv.post && pv.post.id) {
        api.updatePostInModel(pv.post.id, pv);
    }
}

function applyCommentViewResult(result, api) {
    var cv = result.comment_view;
    if (cv && cv.comment && cv.comment.id) {
        api.updateCommentVote(cv.comment.id,
                              cv.my_vote ? cv.my_vote : 0,
                              cv.counts ? (cv.counts.score || 0) : 0);
    }
}
