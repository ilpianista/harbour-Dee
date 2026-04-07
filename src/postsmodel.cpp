#include "postsmodel.h"

int PostsModel::rowCount(const QModelIndex &parent) const {
  Q_UNUSED(parent);
  return m_posts.size();
}

int PostsModel::count() const { return m_posts.size(); }

QVariant PostsModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() >= m_posts.size())
    return QVariant();

  const QJsonObject &post = m_posts.at(index.row());

  // Return the raw JSON object for the default role
  if (role == Qt::UserRole) {
    return QVariant::fromValue(post);
  }

  return QVariant();
}

QHash<int, QByteArray> PostsModel::roleNames() const {
  QHash<int, QByteArray> roles;
  roles[Qt::UserRole] = "postData";
  return roles;
}

void PostsModel::clear() {
  beginResetModel();
  m_posts.clear();
  endResetModel();

  emit countChanged();
}

void PostsModel::append(const QJsonArray &newPosts) {
  int start = rowCount();
  int count = newPosts.size();
  if (count == 0)
    return;

  beginInsertRows(QModelIndex(), start, start + count - 1);
  for (const auto &value : newPosts) {
    m_posts.append(value.toObject());
  }
  endInsertRows();

  emit countChanged();
}
