/// サーバー(functions/src/pvpMatch.ts の OPPONENT_POOL)が対戦相手デッキとして返すカードのうち、
/// クライアントのシードカード(seed_cards_data.dart)に存在しないIDの英語名。
/// サーバーが nameEn を返さない旧バージョンでも英語表示で日本語が出ないようにする。
/// OPPONENT_POOL を変更したらここも更新すること(test/seed_card_names_test.dart が整合を検証)。
const opponentPoolNamesEn = <String, String>{
  'anger_c2_003': 'Flame of Wrath',
  'sadness_c2_004': 'Spirit of Tears',
  'joy_c2_003': 'Circle of Joy',
  'anger_c3_003': 'Hellfire Warrior',
  'sadness_c3_003': 'Witch of Tears',
};
