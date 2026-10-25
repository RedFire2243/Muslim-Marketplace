import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:muslim_marketplace/src/ai/gemini_client.dart';
import 'package:muslim_marketplace/src/config/app_config.dart';
import 'package:muslim_marketplace/src/domain/listing.dart';
import 'package:muslim_marketplace/src/domain/profile.dart';
import 'package:muslim_marketplace/src/domain/taxonomy.dart';
import 'package:muslim_marketplace/src/matching/gemini_search.dart';
import 'package:muslim_marketplace/src/matching/intent_parser.dart';
import 'package:muslim_marketplace/src/matching/matcher.dart';
import 'package:muslim_marketplace/src/ui/theme.dart';
import 'package:muslim_marketplace/src/voice/speech_transcriber.dart';

/// Opt-in device network check. Build this entry point with VOICE_SEARCH_URL
/// and VOICE_SMOKE_AUDIO (a synthetic WAV). No account data or microphone is used.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final report = <String, Object?>{
    'configured': config.hasVoiceSearch,
    'directGemini': config.hasDirectGemini,
    'phase': 'starting',
  };
  final receipt = File('${Directory.systemTemp.path}/voice_probe.json');
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    report['interfaces'] = [
      for (final interface in interfaces)
        {
          'name': interface.name,
          'addresses': [
            for (final address in interface.addresses) address.address,
          ],
        },
    ];
  } catch (error) {
    report['interfaceErrorType'] = error.runtimeType.toString();
  }
  await receipt.writeAsString(jsonEncode(report));
  runApp(const _ProbeScreen(message: 'Checking voice service…'));
  debugPrint('VOICE_DEVICE_PROBE configured=${config.hasVoiceSearch}');
  if (!config.hasVoiceSearch) {
    debugPrint('VOICE_DEVICE_PROBE failed=missing_endpoint');
    runApp(const _ProbeScreen(message: 'Voice endpoint is missing.'));
    return;
  }
  final SpeechTranscriber transcriber;
  final VoidCallback dispose;
  if (config.hasDirectGemini) {
    final direct = DirectGeminiTranscriber(
      apiKey: config.geminiApiKey,
      model: config.geminiModel,
      client: _ProbeClient(report),
    );
    transcriber = direct;
    dispose = direct.dispose;
  } else {
    final backend = BackendSpeechTranscriber(
      url: config.voiceSearchUrl,
      client: _ProbeClient(report),
    );
    transcriber = backend;
    dispose = backend.dispose;
  }
  try {
    const encoded = String.fromEnvironment('VOICE_SMOKE_AUDIO');
    final transcript = await transcriber.transcribe(base64Decode(encoded));
    final text = transcript.toLowerCase();
    if (!text.contains('robotics') || !text.contains('mentor')) {
      throw const VoiceSearchException(
        'The test recording wasn’t transcribed.',
      );
    }
    report['voicePassed'] = true;
    if (config.hasDirectGemini) {
      final parsed = const DeterministicParser().parseSearch(transcript);
      final now = DateTime.now().toUtc();
      final searchClient = GeminiClient(
        apiKey: config.geminiApiKey,
        model: config.geminiModel,
        client: _ProbeClient(report),
      );
      try {
        final selection = await GeminiSearch(client: searchClient).search(
          query: transcript,
          listings: [
            Listing(
              id: 'synthetic-mentor-listing',
              ownerId: 'synthetic-mentor',
              title: 'Robotics mentorship',
              description:
                  'I mentor engineering students on robotics projects in New Brunswick.',
              type: ListingType.mentorship,
              direction: ListingDirection.offer,
              category: ListingCategory.engineering,
              tags: const ['robotics'],
              areaId: parsed.areaId,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          members: [
            MemberProfile(
              id: 'synthetic-mentor',
              displayName: 'Synthetic mentor',
              details: MemberDetails(
                skills: const ['robotics'],
                offeringSummary: 'I mentor students in robotics.',
                areaId: parsed.areaId,
              ),
            ),
            const MemberProfile(
              id: 'synthetic-accountant',
              displayName: 'Synthetic accountant',
              details: MemberDetails(
                skills: ['accounting'],
                offeringSummary: 'I prepare bookkeeping reports.',
              ),
            ),
          ],
          parsed: parsed,
          context: MatchContext(now: now, viewerId: 'synthetic-viewer'),
        );
        report['directoryPassed'] = selection.memberIds.contains(
          'synthetic-mentor',
        );
        report['listingSearchPassed'] = selection.listingIds.contains(
          'synthetic-mentor-listing',
        );
        if (report['directoryPassed'] != true ||
            report['listingSearchPassed'] != true) {
          throw const VoiceSearchException(
            'Gemini search did not find the known test mentor.',
          );
        }
      } finally {
        searchClient.dispose();
      }
    }
    debugPrint('VOICE_DEVICE_PROBE passed=true');
    report['phase'] = 'passed';
    runApp(
      const _ProbeScreen(message: 'Voice service check passed', passed: true),
    );
  } on VoiceSearchException catch (error) {
    report['phase'] = 'failed';
    report['error'] = error.message;
    debugPrint('VOICE_DEVICE_PROBE failed=${error.message}');
    runApp(_ProbeScreen(message: error.message));
  } catch (error) {
    report['phase'] = 'failed';
    report['errorType'] = error.runtimeType.toString();
    debugPrint('VOICE_DEVICE_PROBE failed_type=${error.runtimeType}');
    runApp(const _ProbeScreen(message: 'The voice service check failed.'));
  } finally {
    await receipt.writeAsString(jsonEncode(report));
    dispose();
  }
}

/// This opt-in tool records connection diagnostics only. Request bodies,
/// authentication headers and transcripts are never included in the receipt.
class _ProbeClient extends http.BaseClient {
  _ProbeClient(this.report);
  final Map<String, Object?> report;
  final _inner = IOClient(
    HttpClient()..connectionTimeout = const Duration(seconds: 5),
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final response = await _inner.send(request);
      report['httpStatus'] = response.statusCode;
      return response;
    } on http.ClientException catch (error) {
      report['transportError'] = error.message;
      if (error is SocketException) {
        final socketError = error as SocketException;
        report['address'] = socketError.address?.address;
        report['port'] = socketError.port;
        report['osErrorCode'] = socketError.osError?.errorCode;
      }
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}

class _ProbeScreen extends StatelessWidget {
  const _ProbeScreen({required this.message, this.passed = false});
  final String message;
  final bool passed;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  passed ? Icons.check_circle_outline : Icons.mic_none,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Device diagnostic · synthetic audio only',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
