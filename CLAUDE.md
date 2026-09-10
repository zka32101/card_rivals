# card_rivals - Claude Development Context

**Project**: Card Rivals（カードゲーム）
**Status**: 開発中
**Version**: 1.2.1+4

## 概要

Flutter製のマルチプレイヤーカードゲームアプリ。
Firebase / Flutterfire による認証・データベース・Cloud Functions と、
Riverpod による状態管理、ゲーム内パラメータシステムの実装が完了。

## 技術スタック

### Flutter / Dart
- **Flutter**: 3.47.2 (Analysis: errors/fatal-infos/warnings のみ検出)
- **Dart**: 3.13.2
- **SDK要件**: Dart ^3.12.0

### State Management
- **riverpod**: ^2.6.0
- **hooks_riverpod**: ^2.6.0
- **flutter_hooks**: ^0.21.3+1

### Firebase & Cloud
- **firebase_core**: ^3.3.0
- **firebase_auth**: ^5.1.4
- **cloud_firestore**: ^5.1.0
- **firebase_storage**: ^12.1.0
- **cloud_functions**: ^5.1.3

### その他
- **audioplayers**: ^6.0.0 (BGM/SE)
- **purchases_flutter**: ^8.0.0 (課金)
- **share_plus**: ^13.3.0 (SNS共有)

### Node.js Cloud Functions
- **firebase-admin**: ^14.3.0
- **firebase-functions**: ^7.3.2
- **typescript**: ^7.0.2
- **Node**: 20

## ビルド & テスト

```bash
# 依存関係インストール
flutter pub get

# 静的解析（エラー検出のみ）
flutter analyze --no-fatal-infos --no-fatal-warnings

# ユニットテスト実行
flutter test

# リリースビルド
flutter build apk --release
flutter build ios --release
```

## プロジェクト構造

```
card_rivals/
├── lib/                    # Flutter アプリケーション
│   ├── models/            # Data models (freezed)
│   ├── providers/         # Riverpod state providers
│   ├── screens/           # UI screens
│   └── main.dart
├── functions/             # Firebase Cloud Functions (TypeScript)
│   ├── src/               # TypeScript source
│   └── package.json       # Node.js dependencies
├── test/                  # Unit tests
├── .github/workflows/     # CI/CD configuration
└── pubspec.yaml          # Flutter dependencies
```

## CI/CD パイプライン

- `.github/workflows/ios-build.yml` - iOS CI (PR時に自動実行)
- `.github/workflows/claude.yml` - Claude Code 統合
- `.github/workflows/deploy.yml` - デプロイ設定

### CI 検査項目
- iOS ビルド（flutter analyze, flutter test）
- Cloud Functions ビルド（TypeScript コンパイル）
- PR チェック（自動マージ対応）

## 開発ワークフロー

1. **依存関係管理**: Dependabot が定期的にアップデートを提案
2. **ビルド検証**: CI で自動的に検査・テスト実行
3. **マージ**: すべてのチェック通過後、mainへマージ

## ユーザー確認が必要な操作

- ストアへの実公開
- 本番データの破壊的操作
- リポジトリ・ブランチの破壊的操作
- GitHub Secrets 等の機密情報登録
- 課金・契約が発生する操作

## 最新の更新（2026-09-09）

✅ 依存関係アップデート完了:
- firebase-admin 12.7.0 → 14.3.0
- firebase-functions 5.1.1 → 7.3.2
- typescript 5.9.3 → 7.0.2
- 各種 pub 依存関係の更新

CI: すべてのテストとビルドが GREEN ✓
