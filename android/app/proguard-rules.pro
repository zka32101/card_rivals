# WorkManager(google_mobile_ads経由)のWorkDatabaseはRoomがリフレクションで
# コンストラクタを呼び出すため、R8のフルモード最適化がコンストラクタ未使用と
# 誤認識してクラスをabstract化し、起動時に
# "Failed to create an instance of androidx.work.impl.WorkDatabase" でクラッシュする。
# Room生成の *_Impl クラスとそのno-argコンストラクタを明示的に維持する。
-keep class * extends androidx.room.RoomDatabase
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep class **_Impl { *; }
-keepclassmembers class **_Impl {
    public <init>(...);
}
