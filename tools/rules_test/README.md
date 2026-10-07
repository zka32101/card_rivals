# Firestore ルールのテスト（エミュレータ）

`firestore.rules` の許可・拒否を、Firestore エミュレータで確認する。

1. 初回のみ: `npm i @firebase/rules-unit-testing@3 firebase@10 --legacy-peer-deps`（この中、または別の作業フォルダで）
2. エミュレータを起動（Java 11 でも動く jar を直接使う。firebase-tools の `emulators:exec` は Java 21 が必要）  
   `java -jar %USERPROFILE%\.cache\firebase\emulators\cloud-firestore-emulator-v1.19.8.jar --host 127.0.0.1 --port 8080`
3. 実行: `RULES_PATH=<firestore.rules のパス> FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node rules_test.js`

期待: `RESULT pass=25 fail=0`（フレンド・申請・イベント進捗・イベントの許可/拒否と、既存規則の回帰）。
