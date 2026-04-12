#ifndef POSTSMODEL_H
#define POSTSMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <QJsonObject>

class PostsModel : public QAbstractListModel {
  Q_OBJECT
public:
  explicit PostsModel(QObject *parent = nullptr) : QAbstractListModel(parent) {}

  // Model interface
  int rowCount(const QModelIndex &parent = QModelIndex()) const override;
  QVariant data(const QModelIndex &index,
                int role = Qt::DisplayRole) const override;
  QHash<int, QByteArray> roleNames() const override;

  // Custom operations
  void clear();
  void append(const QJsonArray &newPosts);

private:
  QList<QJsonObject> m_posts;
};

#endif // POSTSMODEL_H
