import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';
import '../models/word_model.dart';

class ApiService {
  final GoogleTranslator _translator = GoogleTranslator();
  static const String _dictionaryApiUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';
  static const Duration _timeout = Duration(seconds: 5); // 5초 타임아웃

  /// Searches for an English word with Timeout protection
  Future<DictionaryResult> searchEnglish(String query) async {
    try {
      // 1. API Call with Timeout
      final response = await http.get(Uri.parse('$_dictionaryApiUrl/$query'))
          .timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final entry = data[0];
        
        // Audio
        String? audioUrl;
        if (entry['phonetics'] != null) {
          for (var p in entry['phonetics']) {
            if (p['audio'] != null && p['audio'].toString().isNotEmpty) {
              audioUrl = p['audio'];
              break;
            }
          }
        }

        // Meanings & Synonyms
        List<WordDefinition> meanings = [];
        Set<String> synonymsSet = {};

        if (entry['meanings'] != null) {
          for (var m in entry['meanings']) {
            String partOfSpeech = m['partOfSpeech'] ?? '';
            String definition = '';
            
            if (m['definitions'] != null && m['definitions'].isNotEmpty) {
              definition = m['definitions'][0]['definition'];
            }

            // Translate definition (Minimize translation calls to prevent hanging)
            if (definition.isNotEmpty) {
              try {
                // Translation might hang, so we limit it strictly
                var translation = await _translator.translate(definition, to: 'ko')
                    .timeout(_timeout);
                var posTranslation = await _translator.translate(partOfSpeech, to: 'ko')
                    .timeout(const Duration(seconds: 2)); // Short timeout for POS
                meanings.add(WordDefinition(pos: posTranslation.text, def: translation.text));
              } catch (e) {
                // If translation fails/times out, use english definition
                meanings.add(WordDefinition(pos: partOfSpeech, def: definition));
              }
            }

            if (m['synonyms'] != null) {
               m['synonyms'].forEach((s) => synonymsSet.add(s.toString()));
            }
            
            // Limit to 2 meanings to speed up
            if (meanings.length >= 2) break; 
          }
        }
        
        String mnemonic = _generateMnemonic(query);

        return DictionaryResult(
          meanings: meanings.take(3).toList(),
          synonyms: synonymsSet.take(5).toList(),
          audioUrl: audioUrl,
          mnemonic: mnemonic,
        );
      } 
    } catch (e) {
      print("Error fetching English word: $e");
    }

    // Fallback: Just translate the word itself
    try {
      var translation = await _translator.translate(query, to: 'ko').timeout(_timeout);
      return DictionaryResult(
        meanings: [WordDefinition(pos: "번역", def: translation.text)],
        mnemonic: "이 단어는 특별한 암기법이 없네요. 소리내어 3번 읽어보세요!",
      );
    } catch (e) {
      return DictionaryResult(
        meanings: [WordDefinition(pos: "오류", def: "검색에 실패했습니다. ($e)")],
        mnemonic: "인터넷 연결을 확인해주세요.",
      );
    }
  }

  String _generateMnemonic(String word) {
    word = word.toLowerCase();
    final Map<String, String> mockMnemonics = {
      'gloomy': '구름이(gloomy) 잔뜩 껴서 우울해..',
      'famine': '빼(fa) 밀리(mi) 네(ne) 밥 다 먹어서 기근이 왔어!',
      'comet': '코 밑(comet)으로 혜성이 지나가네!',
      'voca': '보카(voca)치오가 단어를 외우네!',
      'apple': '애플(apple) 파이는 사과 맛이야.',
      'banana': '바나나(banana)를 먹으면 나한테 반하나?',
    };

    if (mockMnemonics.containsKey(word)) {
      return mockMnemonics[word]!;
    }
    return "단어를 소리나는 대로 읽으며 재밌는 상황을 상상해보세요! ($word)";
  }

  /// Searches for a Korean word with Timeout protection
  Future<DictionaryResult> searchKorean(String query) async {
    try {
      // 1. Translate KR -> EN
      var trans = await _translator.translate(query, to: 'en').timeout(_timeout);
      String engWord = trans.text;

      // 2. Fetch Example
      final response = await http.get(Uri.parse('$_dictionaryApiUrl/$engWord'))
          .timeout(_timeout);
      
      List<EnglishEquivalent> equivalents = [];
      String? audioUrl;
      
      if (response.statusCode == 200) {
         final List<dynamic> data = json.decode(response.body);
         final entry = data[0];

         if (entry['phonetics'] != null) {
          for (var p in entry['phonetics']) {
            if (p['audio'] != null && p['audio'].toString().isNotEmpty) {
              audioUrl = p['audio'];
              break;
            }
          }
        }

         if (entry['meanings'] != null) {
           for (var m in entry['meanings']) {
             if (m['definitions'] != null) {
               for (var d in m['definitions']) {
                 if (d['example'] != null) {
                   equivalents.add(EnglishEquivalent(word: engWord, example: d['example']));
                 }
               }
             }
           }
         }
      }

      if (equivalents.isEmpty) {
        equivalents.add(EnglishEquivalent(word: engWord, example: "No example available."));
      }
      
      return DictionaryResult(
        engEquivalents: equivalents.take(3).toList(),
        korDefinition: "$query (한국어 사전 데이터 없음)", 
        audioUrl: audioUrl
      );

    } catch (e) {
      return DictionaryResult(
        engEquivalents: [EnglishEquivalent(word: "Error", example: "검색 실패.")],
        korDefinition: "오류가 발생했습니다: $e",
      );
    }
  }
}

