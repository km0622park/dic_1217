import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';
import '../models/word_model.dart';

class ApiService {
  final GoogleTranslator _translator = GoogleTranslator();
  static const String _dictionaryApiUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';
  static const Duration _timeout = Duration(seconds: 5); 
  
  // 0. 오프라인 비상 데이터
  static final Map<String, DictionaryResult> _offlineDb = {
    'apple': DictionaryResult(meanings: [WordDefinition(pos: "명사", def: "사과")], mnemonic: "애플(apple) 파이는 사과 맛이야."),
    'banana': DictionaryResult(meanings: [WordDefinition(pos: "명사", def: "바나나")], mnemonic: "바나나(banana)를 먹으면 나한테 반하나?"),
    'school': DictionaryResult(meanings: [WordDefinition(pos: "명사", def: "학교")], mnemonic: "스쿨(school) 버스 타고 학교 가자!"),
    'friend': DictionaryResult(meanings: [WordDefinition(pos: "명사", def: "친구")], mnemonic: "프라이(fry) 팬에 계란 굽는 내 친구(friend)!"),
    'love': DictionaryResult(meanings: [WordDefinition(pos: "동사", def: "사랑하다")], mnemonic: "너를(lo) 브(ve)이! 사랑해~"),
  };

  Future<DictionaryResult> searchEnglish(String query) async {
    String lowerQuery = query.toLowerCase().trim();
    try {
      final response = await http.get(Uri.parse('$_dictionaryApiUrl/$query')).timeout(_timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final entry = data[0];
        String? audioUrl;
        if (entry['phonetics'] != null) {
          for (var p in entry['phonetics']) {
            if (p['audio'] != null && p['audio'].toString().isNotEmpty) {
              audioUrl = p['audio'];
              break;
            }
          }
        }
        List<WordDefinition> meanings = [];
        Set<String> synonymsSet = {};
        if (entry['meanings'] != null) {
          for (var m in entry['meanings']) {
            String partOfSpeech = m['partOfSpeech'] ?? '';
            String definition = '';
            if (m['definitions'] != null && m['definitions'].isNotEmpty) definition = m['definitions'][0]['definition'];
            if (definition.isNotEmpty) {
              try {
                var translation = await _translator.translate(definition, to: 'ko').timeout(_timeout);
                var posTranslation = await _translator.translate(partOfSpeech, to: 'ko').timeout(const Duration(seconds: 2));
                meanings.add(WordDefinition(pos: posTranslation.text, def: translation.text));
              } catch (e) {
                meanings.add(WordDefinition(pos: partOfSpeech, def: definition));
              }
            }
            if (m['synonyms'] != null) m['synonyms'].forEach((s) => synonymsSet.add(s.toString()));
            if (meanings.length >= 2) break;
          }
        }
        String mnemonic = _generateMnemonic(query);
        return DictionaryResult(meanings: meanings.take(3).toList(), synonyms: synonymsSet.take(5).toList(), audioUrl: audioUrl, mnemonic: mnemonic);
      }
    } catch (e) { print("Online failed, trying offline..."); }

    if (_offlineDb.containsKey(lowerQuery)) return _offlineDb[lowerQuery]!;

    try {
      var translation = await _translator.translate(query, to: 'ko').timeout(_timeout);
      return DictionaryResult(meanings: [WordDefinition(pos: "번역", def: translation.text)], mnemonic: "이 단어는 특별한 암기법이 없네요. 소리내어 3번 읽어보세요!");
    } catch (e) {
      return DictionaryResult(meanings: [WordDefinition(pos: "오류", def: "인터넷 연결을 확인해주세요.")], mnemonic: "apple, school 등은 오프라인에서 검색 가능합니다.");
    }
  }

  String _generateMnemonic(String word) {
    if (_offlineDb.containsKey(word.toLowerCase())) return _offlineDb[word.toLowerCase()]!.mnemonic!;
    return "단어를 소리나는 대로 읽으며 재밌는 상황을 상상해보세요! ($word)";
  }

  Future<DictionaryResult> searchKorean(String query) async {
    try {
      var trans = await _translator.translate(query, to: 'en').timeout(_timeout);
      return searchEnglish(trans.text); // 한국어 -> 영어 번역 후 영어 검색 로직 재사용
    } catch (e) {
      return DictionaryResult(engEquivalents: [EnglishEquivalent(word: "Error", example: "검색 실패")], korDefinition: "오류가 발생했습니다.");
    }
  }
}
