import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import '../models/card_frame.dart';
import 'auth_provider.dart';
import 'game_state_provider.dart';

/// 所持/装着フレーム。保存先は users/{uid}/wallet/frames
/// （既存のFirestoreルール `wallet/{document=**}` の本人読み書きに収まるため、ルール変更不要）。
class FrameInventoryNotifier extends StateNotifier<FrameInventory> {
  final String? uid;
  final Ref _ref;
  bool hydrated = false;
  bool _disposed = false;
  bool _busy = false;

  FrameInventoryNotifier(this._ref, this.uid) : super(const FrameInventory()) {
    _load();
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('wallet').doc('frames');

  Future<void> _load() async {
    final u = uid;
    if (u == null) return;
    try {
      final snap = await _doc(u).get();
      if (_disposed) return;
      state = FrameInventory.fromMap(snap.data());
      hydrated = true;
    } catch (e) {
      // 読込失敗時はハイドレートしない（書込を拒否し、実データの上書きを防ぐ）
      debugPrint('Error loading frames: $e');
    }
  }

  Future<bool> _save(FrameInventory inv) async {
    final u = uid;
    if (u == null) return false;
    try {
      await _doc(u).set(inv.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error saving frames: $e');
      return false;
    }
  }

  /// 購入。成功時は success、残高不足/所持済み等はその理由、
  /// ハイドレート前・保存失敗・処理中は null を返す。
  Future<FramePurchaseStatus?> purchase(String frameId) async {
    final u = uid;
    if (u == null || !hydrated || _busy) return null; // ハイドレート前/処理中は拒否
    _busy = true;
    try {
      final walletNotifier = _ref.read(walletProvider.notifier);
      final oldWallet = _ref.read(walletProvider);
      final oldInv = state;
      final r = purchaseFrameLogic(oldWallet, oldInv, frameId);
      if (!r.ok) return r.status;
      // 楽観更新 → wallet保存。失敗したら巻き戻す
      walletNotifier.state = r.wallet;
      state = r.inventory;
      final walletOk = await updateWallet(u, r.wallet);
      if (!walletOk) {
        walletNotifier.state = oldWallet;
        state = oldInv;
        return null;
      }
      final invOk = await _save(r.inventory);
      if (!invOk) {
        // 所持を保存できなかった場合は返金して巻き戻す（残高だけ減るのを防ぐ）
        walletNotifier.state = oldWallet;
        state = oldInv;
        await updateWallet(u, oldWallet);
        return null;
      }
      return FramePurchaseStatus.success;
    } finally {
      _busy = false;
    }
  }

  Future<bool> equip(String frameId) => _change(equipFrameLogic(state, frameId));
  Future<bool> unequip() => _change(unequipFrameLogic(state));

  Future<bool> _change(FrameInventory next) async {
    if (uid == null || !hydrated) return false;
    final old = state;
    state = next;
    final ok = await _save(next);
    if (!ok) state = old;
    return ok;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final frameInventoryProvider = StateNotifierProvider<FrameInventoryNotifier, FrameInventory>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return FrameInventoryNotifier(ref, uid);
});

/// 自分のカード表示に使う装着中フレームID（未装着/無効はnull）
final equippedFrameIdProvider = Provider<String?>((ref) => ref.watch(frameInventoryProvider).validEquippedId);
