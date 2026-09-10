# Card Rivals 自動ビルド・デプロイガイド

**目次**
- [概要](#概要)
- [セットアップ](#セットアップ)
- [トリガー方法](#トリガー方法)
- [iOS 対応](#iOS-対応)
- [自動マージ設定](#自動マージ設定)
- [チェックリスト](#チェックリスト)

---

## 概要

GitHub Actions を使用した自動ビルドシステムが実装されています。
以下のアーティファクトが自動生成・保存されます：

- **APK** (Android Package) - Google Play Store テスト配布用
- **AAB** (Android App Bundle) - Google Play Store 本番配布用
- **iOS** (ipa) - TestFlight/App Store 配布用（※ 設定後）

---

## セットアップ

### 1️⃣ Firebase 設定

**google-services.json の登録**

```bash
# Firebase Console から android/app/google-services.json をダウンロード
# リポジトリの Settings > Secrets and variables > Actions で登録
```

**GitHub Secret:**
```
名前: GOOGLE_SERVICES_JSON
値: android/app/google-services.json の内容（JSON全体をコピー）
```

### 2️⃣ Android signing key の登録

**keystore ファイルの準備**

```bash
# 既存の release keystore がある場合
keytool -list -v -keystore android/app/card_rivals_release.jks

# 新規作成の場合
keytool -genkey -v -keystore android/app/card_rivals_release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias card_rivals_key
```

**Base64 エンコードして登録**

```bash
base64 -i android/app/card_rivals_release.jks -o keystore_base64.txt
```

**GitHub Secrets:**
```
ANDROID_KEYSTORE_BASE64: <base64 エンコード済み keystore>
ANDROID_KEYSTORE_PASSWORD: <keystore パスワード>
ANDROID_KEY_ALIAS: card_rivals_key
ANDROID_KEY_PASSWORD: <key パスワード>
```

### 3️⃣ Dependabot auto-merge 設定（オプション）

```yaml
# .github/workflows/auto-merge.yml で自動設定済み
# PR が自動でマージされるように設定されています
```

---

## トリガー方法

### 方法1️⃣: タグプッシュ（推奨）

```bash
# バージョンタグを作成・プッシュ
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0

# ビルド開始（自動トリガー）
# → GitHub Actions で deploy.yml が実行
```

### 方法2️⃣: GitHub CLI

```bash
gh workflow run deploy.yml \
  -f release_type=production \
  -r main
```

### 方法3️⃣: GitHub MCP Tools（Claude Code）

```javascript
mcp__github__actions_run_trigger
  method: "run_workflow"
  owner: "zka32101"
  repo: "card_rivals"
  workflow_id: "deploy.yml"
  ref: "main"
  inputs: {
    "release_type": "production"
  }
```

### 方法4️⃣: GitHub API (curl)

```bash
curl -X POST \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/zka32101/card_rivals/actions/workflows/deploy.yml/dispatches \
  -d '{"ref":"main", "inputs":{"release_type":"production"}}'
```

---

## ビルド成果物の確認

### アーティファクトの位置

```
GitHub Actions Run
├── Artifacts
│   ├── card-rivals-apk (*.apk)
│   └── card-rivals-aab (*.aab)
```

**保持期間:** 30日

### ダウンロード

```bash
# GitHub CLI でダウンロード
gh run download <RUN_ID> -n card-rivals-apk

# または GitHub UI から Artifacts タブをクリック
```

---

## iOS 対応

### 現在の状態
- ❌ iOS ビルドは無効化中（`build-ios-template` ジョブ）
- ⏳ 有効化には iOS signing 設定が必要

### iOS 有効化手順

**1. Provisioning Profile の取得**

```bash
# Apple Developer Portal から:
# - Certificates: iOS Distribution certificate をダウンロード
# - Identifiers: com.card_rivals を登録
# - Provisioning Profiles: iOS App Distribution を作成
```

**2. GitHub Secrets 登録**

```
IOS_SIGNING_CERTIFICATE: <p12 ファイルを base64 エンコード>
IOS_CERTIFICATE_PASSWORD: <証明書のパスワード>
IOS_PROVISIONING_PROFILE: <.mobileprovision ファイルを base64 エンコード>
IOS_PROVISIONING_PROFILE_SPECIFIER: iOS App Distribution
```

**3. ワークフロー有効化**

`.github/workflows/deploy.yml` の `build-ios-template` ジョブで：

```yaml
if: false  # ← true に変更
```

---

## 自動マージ設定

### Dependabot PRs の自動マージ

`.github/workflows/auto-merge.yml` で以下の依存関係の PR が自動マージされます：

- `flutter`
- `firebase` 関連
- `riverpod`
- `typescript`
- `firebase-admin`
- `firebase-functions`

**トリガー条件:**
- PR が Dependabot で作成
- CI（analyze-and-test）が成功
- 上記の依存関係が含まれている

### Branch Protection 設定（推奨）

Settings > Branches > Add rule:

```
Branch name pattern: main
✓ Require a pull request before merging
✓ Require status checks to pass
  - analyze-and-test
  - build-ios (iOS 有効化後)
✓ Allow auto-merge
```

---

## バージョン管理

### pubspec.yaml の版管理

```yaml
version: 1.2.0+3
```

- `1.2.0`: アプリバージョン（Semantic Versioning）
- `3`: ビルド番号（自動インクリメント）

### ワークフロー内での version 抽出

```bash
# タグから自動抽出
git tag -a v1.2.0 → version=1.2.0, build_number=<git rev-list count>

# workflow_dispatch の場合
→ version=1.0.0, build_number=<unix timestamp>
```

---

## トラブルシューティング

### Google Services JSON が設定されていない

```
Error: Secret GOOGLE_SERVICES_JSON is not set
```

**解決:**
1. Firebase Console から `android/app/google-services.json` をダウンロード
2. Settings > Secrets > GOOGLE_SERVICES_JSON として登録

### Android keystore が設定されていない

```
Warning: Secret ANDROID_KEYSTORE_BASE64 is not set
```

**現象:** Debug keystore でビルド（Google Play Store には配布不可）

**解決:** 上記「セットアップ > Android signing key」を参照

### ビルド失敗: "flutter: command not found"

```
Error: flutter command not found
```

**解決:**
- Flutter バージョンを確認: `.github/workflows/deploy.yml` の `FLUTTER_VERSION`
- 必要に応じて更新してコミット

---

## チェックリスト

本番リリース前の確認:

- [ ] `GOOGLE_SERVICES_JSON` シークレットが設定済み
- [ ] `ANDROID_KEYSTORE_BASE64` 等の signing key が設定済み
- [ ] `pubspec.yaml` のバージョン番号が正確
- [ ] タグ形式が `v*` パターン（例：v1.2.0）
- [ ] ローカルビルドでテスト: `flutter build apk --release`
- [ ] CI が全て成功 (analyze-and-test 等)
- [ ] APK/AAB がアーティファクトにアップロード完了
- [ ] GitHub Releases に release notes を作成（オプション）

---

## 参考資料

- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Flutter Build Documentation](https://flutter.dev/docs/deployment/android)
- [Firebase Setup for Flutter](https://firebase.flutter.dev/docs/overview/)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
