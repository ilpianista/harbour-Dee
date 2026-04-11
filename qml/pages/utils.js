function getRelativeTime(dateString) {
    var date = new Date(dateString)
    var now = new Date()
    var diffMs = now - date
    var diffSec = Math.floor(diffMs / 1000)
    var diffMin = Math.floor(diffSec / 60)
    var diffHour = Math.floor(diffMin / 60)
    var diffDay = Math.floor(diffHour / 24)

    if (diffSec < 60) {
        return qsTr("just now")
    } else if (diffMin < 60) {
        return qsTr("%1 min(s) ago").arg(diffMin)
    } else if (diffHour < 24) {
        return qsTr("%1 hour(s) ago").arg(diffHour)
    } else if (diffDay < 7) {
        return qsTr("%1 day(s) ago").arg(diffDay)
    } else {
        return Qt.formatDateTime(date)
    }
}
