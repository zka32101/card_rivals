# card_rivals - Claude Development Context

**Project**: Card Rivals（カードゲーム）
**Status**: 開発中

## 概要

Flutter製のカードゲームアプリ。詳細は今後の開発サイクルで随時更新する。

## ビルド

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## CI/CD

- `.github/workflows/claude.yml` / `deploy.yml` / `ios-build.yml`

## 開発方針（yourwish オーケストレーター管理下）

このリポジトリは `■■管理■■`（yourwish リポジトリの orchestrator スキル）の管理対象。
標準タスクサイクル（ビルド確認 → セキュリティレビュー → コードレビュー → UI改善 → 不要機能無効化 → PR作成 → CI green → auto-merge）で自動的に開発を進める。

ユーザー確認が必要なのは以下のみ:
- ストアへの実公開
- 本番データの破壊的操作
- リポジトリ・ブランチの破壊的操作
- GitHub Secrets 等のユーザーしか登録できない情報
- 課金・契約が発生する操作
