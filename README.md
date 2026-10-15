# card_rivals

Card Rivals - A competitive card battle game.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## pvpMatches の TTL (自動削除)

`pvpMatch` が作る `pvpMatches/{matchId}` には `expireAt` (作成から30日後の Timestamp) が入ります。
Firestore の TTL ポリシーはコードでは作れないため、デプロイ後に一度だけ手動で設定します(共有プロジェクトなので対象を間違えないこと):

```
gcloud firestore fields ttls update expireAt --collection-group=pvpMatches --enable-ttl --project=<PROJECT_ID>
```

- 既に存在する文書には `expireAt` が無いため TTL は効きません(必要なら別途バックフィル)。
- TTL削除は期限後おおむね24時間以内に行われます。
