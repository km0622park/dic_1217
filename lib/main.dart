import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'services/api_service.dart';
import 'models/word_model.dart';

void main() {
  runApp(const AntigravityApp());
}

class AntigravityApp extends StatelessWidget {
  const AntigravityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Dictionary',
      theme: ThemeData(
        primarySwatch: Colors.amber, // Bright and friendly
        scaffoldBackgroundColor: const Color(0xFFFFF9C4), // Light yellow background
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
      home: const DictionaryHome(),
    );
  }
}

class DictionaryHome extends StatefulWidget {
  const DictionaryHome({super.key});

  @override
  State<DictionaryHome> createState() => _DictionaryHomeState();
}

class _DictionaryHomeState extends State<DictionaryHome> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  final ApiService _apiService = ApiService();
  
  // 검색 결과 상태 변수
  String _searchedWord = "";
  bool _isEnglish = true;
  bool _hasResult = false;
  bool _isLoading = false;

  DictionaryResult _result = DictionaryResult();

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    
    // 키보드 내리기
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _searchedWord = query;
      // 한글 포함 여부로 언어 감지
      _isEnglish = !RegExp(r'[가-h]').hasMatch(query); 
    });

    try {
      DictionaryResult result;
      if (_isEnglish) {
        result = await _apiService.searchEnglish(query);
      } else {
        result = await _apiService.searchKorean(query);
      }

      setState(() {
        _result = result;
        _hasResult = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _speak(String text) async {
    // 1. Try playing audio URL from API first
    if (_result.audioUrl != null && _result.audioUrl!.isNotEmpty) {
      try {
        // Just use TTS for now as AudioPlayer requires extra package (audioplayers/just_audio)
        // and adding native dependencies might complicate the build without verification.
        // We will stick to TTS for simplicity and reliability in this specific environment request.
        // If user explicitly asks for native audio, we can add it.
        // For now, let's use the TTS engine for consistent playback 
        await flutterTts.setLanguage("en-US");
        await flutterTts.speak(text);
        return;
      } catch (e) {
        print("Audio play error: $e");
      }
    }
    
    // 2. Fallback to TTS
    await flutterTts.setLanguage("en-US");
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antigravity Dictionary'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 검색창
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '단어를 입력하세요 (예: Gloomy)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.orange, size: 30),
                    onPressed: () => _search(_controller.text),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onSubmitted: _search,
              ),
            ),
            const SizedBox(height: 20),
            
            // 로딩 인디케이터 또는 결과 화면
            if (_isLoading)
               const CircularProgressIndicator()
            else if (_hasResult) 
               Expanded(child: _buildResultView()),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return ListView(
      children: [
        // 1. 검색어 헤더 및 발음 버튼
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _searchedWord,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              if (_isEnglish)
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 36, color: Colors.orange),
                  onPressed: () => _speak(_searchedWord),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. 검색 결과 표시 (영어 vs 한국어 분기)
        if (_isEnglish) ...[
          // [영어 검색 결과]
          
          /* 암기 꿀팁 (Mnemonic) 추가 */
          if (_result.mnemonic != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.lightGreen.shade100, // 파스텔 그린
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                   Row(
                     children: const [
                       Icon(Icons.lightbulb, color: Colors.orange, size: 28),
                       SizedBox(width: 8),
                       Text("암기 꿀팁!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                     ],
                   ),
                   const SizedBox(height: 8),
                   Text(
                     _result.mnemonic!,
                     style: const TextStyle(fontSize: 18, color: Colors.black87),
                     textAlign: TextAlign.center,
                   ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Text("뜻 (Meanings)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 10),
          if (_result.meanings.isEmpty) const Text("No definition found."),
          ..._result.meanings.map((m) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(m.pos.isNotEmpty ? m.pos.substring(0, 1) : "-", style: const TextStyle(fontSize: 14, color: Colors.white)), 
                backgroundColor: Colors.orange,
                radius: 18,
              ),
              title: Text(m.def, style: const TextStyle(fontSize: 18)),
            ),
          )),
          const SizedBox(height: 20),
          const Text("유사어 (Synonyms)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 10),
          if (_result.synonyms.isEmpty) const Text("No synonyms found."),
          Wrap(
            spacing: 8.0,
            children: _result.synonyms.map<Widget>((syn) {
              return ActionChip(
                label: Text(syn, style: const TextStyle(color: Colors.deepPurple)),
                backgroundColor: Colors.purple.shade50,
                onPressed: () {
                  _controller.text = syn;
                  _search(syn);
                },
              );
            }).toList(),
          )

        ] else ...[
          // [한국어 검색 결과]
          const Text("영어 표현 및 예문", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 10),
          if (_result.engEquivalents.isEmpty) const Text("No equivalents found."),
          ..._result.engEquivalents.map((e) => Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              title: Text(e.word, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("예문: ${e.example}", style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
              ),
              trailing: IconButton(
                 icon: const Icon(Icons.volume_up, size: 28, color: Colors.orange),
                 onPressed: () => _speak(e.word),
              ),
            ),
          )),
          const SizedBox(height: 20),
          const Text("국어사전 뜻", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Text(_result.korDefinition ?? "No definition found.", style: const TextStyle(fontSize: 18)),
          ),
        ],
      ],
    );
  }
}
