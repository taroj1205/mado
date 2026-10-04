# Speech recognition engine

Which engine Mado's dictation runs on, and the measurements behind the choice. Measured on 2026-10-05 on an M5 Pro with 64 GB of memory, macOS 26.6.2 (M4-10).

## Decision

**whisper.cpp, with Whisper large-v3-turbo as the model for Japanese and English.**

- It is within about one point of the most accurate engine in both languages: 6.4% CER in Japanese and 4.9% WER in English.
- It finds the language by itself. It picked the right one on all 10 clips, which is what the "Auto-detect (English, 日本語)" setting on the Speech-model manager board needs. Apple's transcriber needs the language before you speak, and gives back nonsense when it's the wrong one.
- It runs in about 1.9 GB of memory and turns a 14-second recording into text in under half a second.
- whisper.cpp is MIT licensed, and so are the Whisper weights. Its builds publish a prebuilt XCFramework (`whisper-b5130-xcframework.zip` came out with 1.9.4) that Swift Package Manager can use as a binary target. It is built for macOS 13.3 and later. Swift 6.4 from Xcode 27, in Swift 6 language mode, called its C API and transcribed a Japanese and an English clip, with the language auto-detected. Models are separate files, so they fit the download, choose and delete flow of M4-12.

Not chosen:

- **Apple SpeechTranscriber** is the runner-up. It needs no download, answers in about 0.15 s and uses under 100 MB. It lost on Japanese accuracy (8.8%) and on language handling: there is no auto-detect, and Apple documents custom words (`contextualStrings`) only for DictationTranscriber, which was the least accurate engine here.
- **Qwen3-ASR 1.7B** was the most accurate in Japanese (5.2%), but its peak memory footprint was 5.5–6.4 GB, about three times Whisper's. It runs through MLX and a 0.0.x Swift package.
- **Qwen3-ASR 0.6B** matched Whisper in English but was weaker in Japanese (10.0%), and still peaked at 3.3–4.1 GB.
- **Whisper small** was the least accurate in Japanese (16.8%).

## Results

5 Japanese and 5 English recordings, the same clips for every engine. Japanese is scored by character error rate (CER), English by word error rate (WER). Lower is better.

| Engine | Japanese CER | English WER | Time per clip (median, ja / en) | Model load | Peak memory | Download |
| --- | --- | --- | --- | --- | --- | --- |
| Apple SpeechTranscriber | 8.8% | 6.8% | 0.17 s / 0.15 s | 0.09 s | 74–86 MB RSS | None in the app. macOS installs it on demand: 341 MB ja, 380 MB en |
| Apple DictationTranscriber | 15.2% | 13.6% | 0.34 s / 0.17 s | 0.10 s | 120–146 MB RSS | None in the app (macOS) |
| Whisper small (whisper.cpp) | 16.8% | 6.8% | 0.27 s / 0.17 s | 0.13 s | 847 MB RSS, 867 MB footprint | 488 MB |
| **Whisper large-v3-turbo (whisper.cpp)** | **6.4%** | **4.9%** | 0.39 s / 0.31 s | 0.48 s | 1.9 GB RSS, 1.9 GB footprint | 1.6 GB |
| Qwen3-ASR 0.6B, 8-bit | 10.0% | 4.9% | 0.16 s / 0.11 s | 1.10 s | 1.1 GB RSS, 4.1 GB footprint | 1.0 GB |
| Qwen3-ASR 1.7B, 8-bit | 5.2% | 5.8% | 0.34 s / 0.27 s | 1.33 s | 2.5 GB RSS, 6.4 GB footprint | 2.5 GB |

Time per clip is from audio in to text out with the model already loaded, which is what you wait for after letting go of the hotkey. Every engine was well under real time: the slowest took 0.039 s per second of audio.

Apple's model runs in the system's `localspeechrecognition` process and on the Neural Engine. Its row is that process's peak RSS. Neural Engine memory isn't counted against any process, so the Apple rows understate the true cost.

## Per clip

Error rate / time to transcribe.

| Clip | Length | Apple Speech | Apple Dictation | Whisper small | Whisper turbo | Qwen3 0.6B | Qwen3 1.7B |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ja1 | 10.4 s | 0.0% / 0.15 s | 0.0% / 0.16 s | 6.7% / 0.27 s | 0.0% / 0.38 s | 6.7% / 0.13 s | 11.1% / 0.25 s |
| ja2 | 14.2 s | 0.0% / 0.17 s | 0.0% / 0.28 s | 4.3% / 0.29 s | 0.0% / 0.39 s | 0.0% / 0.16 s | 0.0% / 0.34 s |
| ja3 | 12.8 s | 12.7% / 0.28 s | 31.0% / 0.53 s | 22.5% / 0.37 s | 9.9% / 0.47 s | 5.6% / 0.24 s | 0.0% / 0.49 s |
| ja4 | 12.5 s | 16.1% / 0.18 s | 19.6% / 0.62 s | 30.4% / 0.27 s | 8.9% / 0.40 s | 23.2% / 0.16 s | 7.1% / 0.36 s |
| ja5 | 12.1 s | 12.5% / 0.12 s | 15.6% / 0.34 s | 12.5% / 0.20 s | 12.5% / 0.39 s | 15.6% / 0.10 s | 12.5% / 0.22 s |
| en1 | 10.6 s | 5.3% / 0.15 s | 5.3% / 0.17 s | 5.3% / 0.17 s | 5.3% / 0.31 s | 5.3% / 0.12 s | 5.3% / 0.27 s |
| en2 | 8.8 s | 9.5% / 0.15 s | 19.0% / 0.22 s | 4.8% / 0.18 s | 9.5% / 0.32 s | 9.5% / 0.11 s | 9.5% / 0.27 s |
| en3 | 11.5 s | 9.1% / 0.22 s | 24.2% / 0.36 s | 12.1% / 0.26 s | 3.0% / 0.37 s | 3.0% / 0.18 s | 6.1% / 0.37 s |
| en4 | 5.8 s | 6.7% / 0.13 s | 6.7% / 0.17 s | 6.7% / 0.15 s | 6.7% / 0.30 s | 6.7% / 0.09 s | 6.7% / 0.19 s |
| en5 | 4.3 s | 0.0% / 0.11 s | 0.0% / 0.13 s | 0.0% / 0.15 s | 0.0% / 0.30 s | 0.0% / 0.08 s | 0.0% / 0.18 s |

Most Japanese errors are rare words: カタルーニャ, 口蓋, 歯列 and 磁気反転. Every engine got the plain sentences in ja1 and ja2 nearly right.

## Language

- **Whisper** detected the language by itself on all 10 clips, with both small and large-v3-turbo.
- **Apple** needs the locale up front. English read as `ja_JP` came back as "Mayeplentn atesnstersecause havehr thankony。". One Japanese clip read as `en_US` came back empty.
- If Apple is ever used, the language has to come from somewhere reliable: a setting, or the input source when dictation starts.

## Notes for M4-11 and M4-12

- **Whisper small isn't a good default for Japanese.** The Speech-model manager board marks it "recommended", but it was the least accurate in Japanese here. The board's "best for Japanese" label on Large v3 Turbo matches the results. Which model is the default is M4-12's call; this is the evidence for it.
- **There are no partial results.** whisper.cpp transcribes after you let go of the hotkey, so text appears in one go, 0.3–0.4 s after letting go on this Mac. Apple's transcriber can stream partial text while you speak.
- **Memory stays used while the model is loaded.** Large-v3-turbo holds about 1.9 GB until it is unloaded. Unloading after a while idle gives that back, at the cost of the 0.5 s load on the next use.
- **Load the ggml backends first.** whisper.cpp built with dynamically loaded backends, like the Homebrew build, aborts in `whisper_init_from_file_with_params` unless `ggml_backend_load_all()` runs first. `whisper-cli` does this itself. The XCFramework build wasn't checked.
- **Apple DictationTranscriber quirk.** With the `.shortDictation` preset it never marks a result final, even after `finalizeAndFinish(through:)`. The last result arrives with `isFinal == false` and then the stream ends. Code that keeps only final results gets an empty string.

## Researched, not measured

- **Fun-ASR-MLT-Nano-2512** tops one FLEURS Japanese ranking at 2.32% CER ([Handy](https://models.handy.computer/languages/ja)), but it uses the FunASR model license, not an OSI one.
- **SenseVoice Small** is very fast but scores 7.63% Japanese CER on the same ranking, and also uses the FunASR license.
- **Parakeet TDT 0.6B v3** covers 25 European languages and no Japanese.
- **kotoba-whisper v2.0** is Japanese-only.
- **WhisperKit** runs the same Whisper models through Core ML. It would change the runtime, not the model.

## Not measured

- **Slower Macs and less memory**, such as an M1 with 8 GB. Everything ran on one M5 Pro with 64 GB.
- **Mixed Japanese and English in one sentence**, such as English product names inside Japanese speech.
- **Live microphone input, noise and distance.** FLEURS clips are read speech recorded close to the microphone.
- **More speakers.** All five Japanese clips are male voices, and the English clips are two male and three female. FLEURS doesn't say whether clips share a speaker.

## Sources

- [whisper.cpp README, "XCFramework"](https://github.com/ggml-org/whisper.cpp/tree/v1.9.4#xcframework): the prebuilt XCFramework is meant for Swift projects through a `binaryTarget`. Adopted as the way to ship it.
- [whisper.cpp `build-xcframework.sh` at v1.9.4](https://github.com/ggml-org/whisper.cpp/blob/v1.9.4/build-xcframework.sh): `MACOS_MIN_OS_VERSION=13.3`, so the framework runs on Mado's macOS 26.
- [whisper.cpp releases](https://github.com/ggml-org/whisper.cpp/releases): the 1.9.4 tag has no assets of its own. Build b5130, released the same day, carries `whisper-b5130-xcframework.zip`.
- [whisper.cpp LICENSE](https://github.com/ggml-org/whisper.cpp/blob/v1.9.4/LICENSE) and [OpenAI Whisper README, "License"](https://github.com/openai/whisper#license): the library is MIT, and Whisper's code and model weights are MIT.
- [`SpeechTranscriber`](https://developer.apple.com/documentation/speech/speechtranscriber) and [`isAvailable`](https://developer.apple.com/documentation/speech/speechtranscriber/isavailable): the general-purpose model. It depends on the device's hardware, and Apple suggests DictationTranscriber where it isn't available. It takes a locale up front, with no auto-detect option in the SDK's interface.
- [`DictationTranscriber`](https://developer.apple.com/documentation/speech/dictationtranscriber): the same models as system dictation and on-device `SFSpeechRecognizer`. It is the transcriber Apple documents for custom vocabulary and contextual strings.
- [`AnalysisContext.contextualStrings`](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings): documented for DictationTranscriber only, up to 100 short phrases. This is why Apple's custom-word support counted against SpeechTranscriber.
- [`SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer): `prepareToAnalyze(in:)` preloads the model, and `start(inputAudioFile:finishAfterFile:)` and the `finalize…` methods end a session. These are what the measurements used. Apple's interfaces were read from the Speech framework in the Xcode 27 macOS SDK.
- [Qwen3-ASR-1.7B model card](https://huggingface.co/Qwen/Qwen3-ASR-1.7B): Apache-2.0.
- [FLEURS dataset card](https://huggingface.co/datasets/google/fleurs): the clips and reference transcripts, CC BY 4.0.

The Japanese and English accuracy ranking comes from this document's own measurements, not from published leaderboards. Published FLEURS results were only used to pick which models to measure.

## How it was measured

- **Clips.** The first five distinct sentences in the [FLEURS](https://huggingface.co/datasets/google/fleurs) test archive for `ja_jp` and `en_us` (CC BY 4.0), 16 kHz mono, 4.3–14.2 s long. FLEURS sentence ids: ja1–5 = 1828, 1834, 1813, 1869, 1744; en1–5 = 1904, 1675, 1950, 1728, 1972. The FLEURS raw transcription is the reference.
- **Engines.** Each engine got the language (Japanese or English) up front. Whisper's auto-detect was checked in a separate run.
  - Apple: `SpeechAnalyzer.start(inputAudioFile:finishAfterFile:)`, with `SpeechTranscriber(preset: .transcription)` or `DictationTranscriber(preset: .shortDictation)`. A new analyzer per clip, after one `prepareToAnalyze(in:)` to load the model.
  - Whisper: `whisper-cli` from whisper.cpp 1.9.4 (Homebrew, Metal), with the default 4 threads and beam size 5. The model files are `ggml-small.bin` and `ggml-large-v3-turbo.bin`, checked against their published SHA-256.
  - Qwen3-ASR: `speech transcribe-batch` from soniqo speech-swift 0.0.28 (MLX), with `-m 0.6B-8bit` or `-m 1.7B` (8-bit weights from `aufklarer/Qwen3-ASR-*-MLX-8bit`).
- **Time.** Each run was done twice and the second kept. Time per clip leaves out model load, and model load leaves out the download.
- **Memory.** Whisper and Qwen3: peak RSS and peak memory footprint from `/usr/bin/time -l`. Apple: peak RSS of the `localspeechrecognition` process, sampled every 0.2 s.
- **Scoring.** Both texts are NFKC-normalised and lowercased, and punctuation is removed. Japanese also drops spaces and is compared by character. English is compared by word.
- **Sample size.** One character is 0.4 points of Japanese CER (250 characters) and one word is about 1 point of English WER (103 words), so differences under a couple of points are noise. FLEURS writes "25 to 30 year" in en1 where all six engines heard "years", so every engine loses that word.
