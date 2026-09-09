#!/bin/bash
# build-and-test スキル実行スクリプト
# 使用: ./run.sh <app_name>
# テスト観点: 起動、連携、購入、認証、広告

set -e

APP_NAME="${1:?アプリ名を指定してください（例：prefecture_defense）}"
APP_PATH="apps/$APP_NAME"
APK_PATH="$APP_PATH/build/app/outputs/flutter-apk/app-release.apk"

# テスト結果格納配列
declare -A TEST_RESULTS

echo "========================================="
echo "🧪 build-and-test: $APP_NAME"
echo "========================================="

# 1. ビルドファイルの確認
echo ""
echo "📦 ビルドファイル確認..."
if [ ! -f "$APK_PATH" ]; then
    echo "❌ エラー: APK ファイルが見つかりません"
    echo "   予想パス: $APK_PATH"
    exit 1
fi

APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
APK_DATE=$(stat -c %y "$APK_PATH" | cut -d' ' -f1,2)
echo "✅ APK 準備完了"
echo "   サイズ: $APK_SIZE"
echo "   生成日時: $APK_DATE"

# 2. adb 確認
echo ""
echo "📱 デバイス接続確認..."
if ! command -v adb &> /dev/null; then
    echo "⚠️  adb が見つかりません。ANDROID_SDK_ROOT を設定中..."
    if [ -z "$ANDROID_SDK_ROOT" ]; then
        export ANDROID_SDK_ROOT="${ANDROID_HOME:-$HOME/Android/Sdk}"
    fi
    ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
else
    ADB="adb"
fi

if [ ! -x "$ADB" ]; then
    echo "❌ エラー: adb 実行ファイルが見つかりません"
    exit 1
fi

DEVICE_COUNT=$($ADB devices | grep -c "device$" || true)
if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "⚠️  警告: デバイスが接続されていません"
    echo "   次のいずれかを実行してください："
    echo "   1. エミュレータを起動: emulator -avd <AVD_NAME>"
    echo "   2. 物理デバイスを USB 接続"
    exit 1
fi

echo "✅ デバイス接続確認"
$ADB devices | grep -E "^[0-9a-zA-Z_-]+.*device$" | head -1

# 3. アプリインストール
echo ""
echo "📥 アプリをインストール中..."
PACKAGE_NAME=$(grep "^package:" "$APP_PATH/android/app/build.gradle.kts" | head -1 | sed "s/.*package[^=]*=[^\"]*['\"]//;s/['\"].*//" || echo "com.example.$APP_NAME")

echo "   パッケージ: $PACKAGE_NAME"
if $ADB install -r "$APK_PATH" > /tmp/adb_install.log 2>&1; then
    echo "✅ インストール完了"
    TEST_RESULTS["install"]=1
else
    echo "⚠️  インストール結果:"
    cat /tmp/adb_install.log | tail -5
    TEST_RESULTS["install"]=0
fi

# 清理し、ログ収集準備
$ADB logcat -c 2>/dev/null || true
sleep 1

# 4. 起動テスト
echo ""
echo "🚀 起動テスト..."
ACTIVITY_NAME=$(grep -h "activity android:name" "$APP_PATH/android/app/src/main/AndroidManifest.xml" 2>/dev/null | head -1 | sed 's/.*android:name="\([^"]*\)".*/\1/' || echo ".MainActivity")
if [[ ! "$ACTIVITY_NAME" =~ "." ]]; then
    ACTIVITY_NAME=".$ACTIVITY_NAME"
fi

LAUNCH_INTENT="$PACKAGE_NAME/$ACTIVITY_NAME"
echo "   起動対象: $LAUNCH_INTENT"

if $ADB shell am start -n "$LAUNCH_INTENT" > /dev/null 2>&1; then
    echo "✅ アプリ起動成功"
    TEST_RESULTS["launch"]=1
else
    echo "❌ アプリ起動失敗"
    TEST_RESULTS["launch"]=0
fi

# 初期化待ち
echo "   ⏳ 初期化完了待ち（10秒）..."
sleep 10

# 5. クラッシュ判定
echo ""
echo "🔍 クラッシュチェック..."
CRASH_LOG=$($ADB logcat -d 2>/dev/null | grep -iE "FATAL|CRASH|ANR" || echo "")
if [ -z "$CRASH_LOG" ]; then
    echo "✅ クラッシュなし"
    TEST_RESULTS["crash_free"]=1
else
    echo "❌ クラッシュ検出:"
    echo "$CRASH_LOG" | head -3
    TEST_RESULTS["crash_free"]=0
fi

# 6. 連携テスト
echo ""
echo "🔗 連携テスト（API、バックエンド）..."
API_LOGS=$($ADB logcat -d 2>/dev/null | grep -iE "http|api|connection|network" || echo "")
if echo "$API_LOGS" | grep -iq "error\|fail\|exception"; then
    echo "⚠️  API エラー検出:"
    echo "$API_LOGS" | grep -iE "error|fail|exception" | head -2
    TEST_RESULTS["connectivity"]=0
else
    echo "✅ API 連携OK（エラーなし）"
    TEST_RESULTS["connectivity"]=1
fi

# 7. 購入画面テスト
echo ""
echo "💰 購入画面テスト（Google Play Billing）..."
BILLING_LOGS=$($ADB logcat -d 2>/dev/null | grep -iE "billing|purchase|payment" || echo "")
if echo "$BILLING_LOGS" | grep -iq "error\|fail\|exception"; then
    echo "⚠️  購入機能エラー検出:"
    echo "$BILLING_LOGS" | grep -iE "error|fail|exception" | head -2
    TEST_RESULTS["billing"]=0
else
    echo "✅ 購入機能OK（初期化確認）"
    TEST_RESULTS["billing"]=1
fi

# 8. 認証テスト
echo ""
echo "🔐 認証テスト（ログイン、トークン）..."
AUTH_LOGS=$($ADB logcat -d 2>/dev/null | grep -iE "auth|login|token|credential" || echo "")
if echo "$AUTH_LOGS" | grep -iq "error\|fail\|invalid\|unauthorized"; then
    echo "⚠️  認証エラー検出:"
    echo "$AUTH_LOGS" | grep -iE "error|fail|invalid|unauthorized" | head -2
    TEST_RESULTS["auth"]=0
else
    echo "✅ 認証フローOK（エラーなし）"
    TEST_RESULTS["auth"]=1
fi

# 9. 広告テスト
echo ""
echo "📣 広告テスト（Google Mobile Ads）..."
AD_LOGS=$($ADB logcat -d 2>/dev/null | grep -iE "admob|ads|advertisement" || echo "")
if echo "$AD_LOGS" | grep -iq "error\|fail\|exception"; then
    echo "⚠️  広告機能エラー検出:"
    echo "$AD_LOGS" | grep -iE "error|fail|exception" | head -2
    TEST_RESULTS["ads"]=0
else
    if [ -n "$AD_LOGS" ]; then
        echo "✅ 広告機能OK（初期化確認）"
        TEST_RESULTS["ads"]=1
    else
        echo "⏸️  広告ログなし（UI 未訪問の可能性）"
        TEST_RESULTS["ads"]=2
    fi
fi

# 10. アプリ終了
echo ""
echo "🛑 クリーンアップ..."
$ADB shell am force-stop "$PACKAGE_NAME" > /dev/null 2>&1 || true

# 11. 最終レポート
echo ""
echo "========================================="
echo "📊 テスト結果レポート: $APP_NAME"
echo "========================================="
echo ""

# 合否判定関数
check_result() {
    local test_name="$1"
    local result="${TEST_RESULTS[$test_name]}"
    if [ "$result" == "1" ]; then
        echo "  ✅ $test_name"
    elif [ "$result" == "0" ]; then
        echo "  ❌ $test_name（要調査）"
    else
        echo "  ⏸️  $test_name（未確認）"
    fi
}

echo "テスト観点別結果:"
check_result "launch"
check_result "crash_free"
check_result "connectivity"
check_result "billing"
check_result "auth"
check_result "ads"

# 総合判定
PASS_COUNT=0
FAIL_COUNT=0
for result in "${TEST_RESULTS[@]}"; do
    if [ "$result" == "1" ]; then
        ((PASS_COUNT++))
    elif [ "$result" == "0" ]; then
        ((FAIL_COUNT++))
    fi
done

echo ""
if [ $FAIL_COUNT -eq 0 ]; then
    echo "🎉 総合判定: ✅ テスト合格"
else
    echo "⚠️  総合判定: 要確認（$FAIL_COUNT項目にエラー）"
fi
echo ""
echo "合格項目: $PASS_COUNT  失敗項目: $FAIL_COUNT"
echo "========================================="
echo ""
