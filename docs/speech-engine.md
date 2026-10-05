# Speech recognition engine

Which engine Mado's dictation runs on, and the measurements behind the choice. Measured on 2026-10-05 on an M5 Pro with 64 GB of memory, macOS 26.6.2 (M4-10). The two Parakeet rows were added the same day on the same Mac (M4-15).

## Decision

**whisper.cpp, with Whisper large-v3-turbo as the model for Japanese and English.**

- It is within about one point of the most accurate engine in both languages: 6.4% CER in Japanese and 4.9% WER in English.
- It finds the language by itself. It picked the right one on all 10 clips, which is what the "Auto-detect (English, 日本語)" setting on the Speech-model manager board needs. Apple's transcriber needs the language before you speak, and gives back nonsense when it's the wrong one.
- It runs in about 1.9 GB of memory and turns a 14-second recording into text in under half a second.
- whisper.cpp is MIT licensed, and so are the Whisper weights. Models are separate files, so they fit the download, choose and delete flow of M4-12.
- It can be shipped as an XCFramework through a Swift Package Manager binary target. Build b5130's `whisper-b5130-xcframework.zip` is built from the same commit as the 1.9.4 measured here (`927cfce`), for macOS 13.3 and later. Swift 6.4 from Xcode 27, in Swift 6 language mode, called the 1.9.4 C API from the Homebrew library and transcribed a Japanese and an English clip, with the language auto-detected. The XCFramework itself hasn't been run yet; see the notes for M4-11.

Not chosen:

- **Apple SpeechTranscriber** is the runner-up. Mado wouldn't ship a model for it, it answers in about 0.15 s and its speech process peaked at 36–48 MB. Its models still have to be on the Mac: macOS downloads them from Apple and shares them between apps, and an app that needs a missing language has to request it through `AssetInventory`. It lost on Japanese accuracy (8.8%) and on language handling: there is no auto-detect, and Apple documents custom words (`contextualStrings`) only for DictationTranscriber, which was the least accurate engine here. It also needs macOS 26 (the SDK marks it `@available(anyAppleOS 26, *)`). That fits the plan's minimum of macOS 26, but `project.yml` still declares 14.0. Even on macOS 26 it depends on the hardware, so Apple's path would always need `SpeechTranscriber.isAvailable` and a fallback, plus an OS check while the deployment target is below 26. whisper.cpp runs on macOS 13.3 and later.
- **Qwen3-ASR 1.7B** was the most accurate in Japanese (5.2%), but its peak memory footprint was 5.5–6.4 GB, about three times Whisper's. It runs through MLX and a 0.0.x Swift package.
- **Qwen3-ASR 0.6B** matched Whisper in English but was weaker in Japanese (10.0%), and still peaked at 3.3–4.1 GB.
- **Whisper small** was the least accurate in Japanese (16.8%).
- **Parakeet** is in the model list next to the Whisper models, but is not the default. Both Parakeet models are several times faster than Whisper turbo and use a fraction of its memory, so they were added for people who value speed. Each covers a single language: Parakeet TDT v3 reads English and other European languages but not Japanese, and Parakeet TDT Japanese reads Japanese only. Neither detects the language, so the user picks the model that matches what they speak. Both are less accurate than turbo (9.7% English WER and 12.0% Japanese CER, against 4.9% and 6.4%). See "Parakeet" below.

## Results

5 Japanese and 5 English recordings, the same clips for every engine. Japanese is scored by character error rate (CER), English by word error rate (WER). Lower is better.

| Engine | Japanese CER | English WER | Time per clip (median, ja / en) | Model load | Peak memory | Download |
| --- | --- | --- | --- | --- | --- | --- |
| Apple SpeechTranscriber | 8.8% | 6.8% | 0.17 s / 0.15 s | 0.09 s | 48 MB ja, 36 MB en footprint | Not in the app. macOS downloads it per language through `AssetInventory`: 341 MB ja, 380 MB en (already installed here) |
| Apple DictationTranscriber | 15.2% | 13.6% | 0.34 s / 0.17 s | 0.10 s | 29 MB ja, 28 MB en footprint | Not in the app (macOS, through `AssetInventory`) |
| Whisper small (whisper.cpp) | 16.8% | 6.8% | 0.27 s / 0.17 s | 0.13 s | 847 MB RSS, 867 MB footprint | 488 MB |
| **Whisper large-v3-turbo (whisper.cpp)** | **6.4%** | **4.9%** | 0.39 s / 0.31 s | 0.48 s | 1.9 GB RSS, 1.9 GB footprint | 1.6 GB |
| Qwen3-ASR 0.6B, 8-bit | 10.0% | 4.9% | 0.16 s / 0.11 s | 1.10 s | 1.1 GB RSS, 4.1 GB footprint | 1.0 GB |
| Qwen3-ASR 1.7B, 8-bit | 5.2% | 5.8% | 0.34 s / 0.27 s | 1.33 s | 2.5 GB RSS, 6.4 GB footprint | 2.5 GB |
| Parakeet TDT v3 (FluidAudio) | not supported | 9.7% | not supported / 0.05 s | 0.15 s | 142 MB RSS, 84 MB footprint, plus the Neural Engine | 483 MB |
| Parakeet TDT Japanese (FluidAudio) | 12.0% | not supported | 0.04 s / not supported | 0.18 s | 115 MB RSS, 72 MB footprint, plus the Neural Engine | 619 MB |

Time per clip is from audio in to text out with the model already loaded, which is what you wait for after letting go of the hotkey. Every engine was well under real time. The slowest single clip was Whisper turbo on en5: 0.30 s for 4.3 s of audio, about 0.07 s per second. Whisper turbo took about 0.3 s even for the shortest clips, so its time per clip doesn't shrink much below that.

Parakeet runs as Core ML models on the Neural Engine, so like Apple's, its memory figures leave out what the Neural Engine uses and understate the true cost. Its model load is with the system's compiled copy already cached. The first load after a download took about 10 s while Core ML compiled the models for the Neural Engine, which FluidAudio does at the end of the download.

Apple's model runs in the system's `localspeechrecognition` process and on the Neural Engine. Its row is that process's lifetime peak footprint, the same measure `/usr/bin/time` reports for the other engines. Neural Engine memory isn't counted against any process, so the Apple rows understate the true cost.

## Per clip

Error rate / time to transcribe.

| Clip | Length | Apple Speech | Apple Dictation | Whisper small | Whisper turbo | Qwen3 0.6B | Qwen3 1.7B | Parakeet Japanese | Parakeet v3 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ja1 | 10.4 s | 0.0% / 0.15 s | 0.0% / 0.16 s | 6.7% / 0.27 s | 0.0% / 0.38 s | 6.7% / 0.13 s | 11.1% / 0.25 s | 4.4% / 0.04 s | — |
| ja2 | 14.2 s | 0.0% / 0.17 s | 0.0% / 0.28 s | 4.3% / 0.29 s | 0.0% / 0.39 s | 0.0% / 0.16 s | 0.0% / 0.34 s | 0.0% / 0.04 s | — |
| ja3 | 12.8 s | 12.7% / 0.28 s | 31.0% / 0.53 s | 22.5% / 0.37 s | 9.9% / 0.47 s | 5.6% / 0.24 s | 0.0% / 0.49 s | 35.2% / 0.19 s | — |
| ja4 | 12.5 s | 16.1% / 0.18 s | 19.6% / 0.62 s | 30.4% / 0.27 s | 8.9% / 0.40 s | 23.2% / 0.16 s | 7.1% / 0.36 s | 0.0% / 0.05 s | — |
| ja5 | 12.1 s | 12.5% / 0.12 s | 15.6% / 0.34 s | 12.5% / 0.20 s | 12.5% / 0.39 s | 15.6% / 0.10 s | 12.5% / 0.22 s | 9.4% / 0.04 s | — |
| en1 | 10.6 s | 5.3% / 0.15 s | 5.3% / 0.17 s | 5.3% / 0.17 s | 5.3% / 0.31 s | 5.3% / 0.12 s | 5.3% / 0.27 s | — | 21.1% / 0.05 s |
| en2 | 8.8 s | 9.5% / 0.15 s | 19.0% / 0.22 s | 4.8% / 0.18 s | 9.5% / 0.32 s | 9.5% / 0.11 s | 9.5% / 0.27 s | — | 9.5% / 0.05 s |
| en3 | 11.5 s | 9.1% / 0.22 s | 24.2% / 0.36 s | 12.1% / 0.26 s | 3.0% / 0.37 s | 3.0% / 0.18 s | 6.1% / 0.37 s | — | 9.1% / 0.07 s |
| en4 | 5.8 s | 6.7% / 0.13 s | 6.7% / 0.17 s | 6.7% / 0.15 s | 6.7% / 0.30 s | 6.7% / 0.09 s | 6.7% / 0.19 s | — | 6.7% / 0.05 s |
| en5 | 4.3 s | 0.0% / 0.11 s | 0.0% / 0.13 s | 0.0% / 0.15 s | 0.0% / 0.30 s | 0.0% / 0.08 s | 0.0% / 0.18 s | — | 0.0% / 0.04 s |

Most Japanese errors are rare words: カタルーニャ, 口蓋, 歯列 and 磁気反転. Every engine got the plain sentences in ja1 and ja2 nearly right.

The Parakeet columns show only the language each model supports. Parakeet's ja3 score is one dropped sentence: it left out "バルセロナの公用語はカタルーニャ語とスペイン語です。" at the start and read the rest correctly. Its other four Japanese clips scored 0.0–9.4%.

## Language

- **Whisper** detected the language by itself on all 10 clips, with both small and large-v3-turbo.
- **Apple** needs the locale up front. English read as `ja_JP` came back as "Mayeplentn atesnstersecause havehr thankony。". One Japanese clip read as `en_US` came back empty.
- If Apple is ever used, the language has to come from somewhere reliable: a setting, or the input source when dictation starts.

## Parakeet

M4-15 measured Parakeet through [FluidAudio](https://github.com/FluidInference/FluidAudio) 0.17.5, which runs NVIDIA's Parakeet TDT models as Core ML models. Mado uses `FluidInference/parakeet-tdt-0.6b-v3-coreml` and `FluidInference/parakeet-0.6b-ja-coreml`, both CC-BY-4.0.

- **Faster and lighter than turbo.** The median clip took 0.04–0.05 s against turbo's 0.31–0.39 s, and the process peaked at 72–84 MB of footprint against 1.9 GB. The Neural Engine's share isn't counted, so the real gap is smaller than the numbers say.
- **Less accurate than turbo.** 9.7% English WER (turbo 4.9%) and 12.0% Japanese CER (turbo 6.4%). The English gap is five words out of 103.
- **One language per model.** Parakeet TDT v3 gives nonsense for Japanese (160% CER, for example "Intannet tik taj tik..."). Parakeet TDT Japanese turned all five English clips into short Japanese phrases such as "そうですね。". There is no auto-detect, so the "Auto-detect (English, 日本語)" setting only works with a Whisper model.
- **Downloads are not checksummed.** FluidAudio fetches the model files from Hugging Face's `main` branch. Mado downloads them into a staging folder, moves it into place when the download finishes, and loads the models with `AsrModels.loadLocal`, which never downloads.
- **In the app.** Both models are in the model list and work in dictation. Turbo stays the recommended model, and Parakeet is rated Fastest with Medium accuracy.

## Notes for M4-11 and M4-12

- **Whisper small isn't a good default for Japanese.** The Speech-model manager board marks it "recommended", but it was the least accurate in Japanese here. The board's "best for Japanese" label on Large v3 Turbo matches the results. Which model is the default is M4-12's call; this is the evidence for it.
- **Partial results weren't measured.** Only the file path was measured: transcribe after you let go of the hotkey, so text appears in one go, 0.3–0.4 s after letting go on this Mac. whisper.cpp also has a [`whisper-stream` example](https://github.com/ggml-org/whisper.cpp/tree/v1.9.4#real-time-audio-input-example) that re-transcribes the microphone audio every half second. That would give live text at the cost of running the model repeatedly, and its accuracy and load weren't checked. Apple's transcriber streams partial text natively.
- **Memory stays used while the model is loaded.** Large-v3-turbo holds about 1.9 GB until it is unloaded. Unloading after a while idle gives that back, at the cost of the 0.5 s load on the next use.
- **Check the XCFramework before relying on it.** Its build script builds a static library with Metal built in and turns on Core ML with a fallback to Metal. The Homebrew library measured here loads its backends dynamically and has no Core ML. So the first step of M4-11 is to pin `whisper-b5130-xcframework.zip` by checksum, run one clip through it on macOS 26 and confirm it falls back to Metal when no Core ML encoder file sits next to the model.
- **Load the ggml backends first with a dynamic build.** The Homebrew library aborts in `whisper_init_from_file_with_params` unless `ggml_backend_load_all()` runs first. `whisper-cli` does this itself. A static build like the XCFramework links its backends in, so this probably doesn't apply there, but that hasn't been checked.
- **Apple DictationTranscriber quirk.** With the `.shortDictation` preset it never marks a result final, even after `finalizeAndFinish(through:)`. The last result arrives with `isFinal == false` and then the stream ends. Code that keeps only final results gets an empty string.

## Researched, not measured

- **Fun-ASR-MLT-Nano-2512** is an 800M-parameter model covering 31 languages, Japanese and English among them, under Apache-2.0 ([model card](https://huggingface.co/FunAudioLLM/Fun-ASR-MLT-Nano-2512)). Its model card publishes no Japanese accuracy. The only figure found is a third-party FLEURS run at 2.32% CER ([Handy](https://models.handy.computer/languages/ja)), which hasn't been confirmed here. Upstream runs it through FunASR, a Python and PyTorch toolkit, with no Swift or Core ML runtime. It wasn't measured, and it is the first model to measure if Japanese accuracy needs to improve.
- **SenseVoice Small** covers Japanese and English under the FunASR model license, not an OSI license ([model card](https://huggingface.co/FunAudioLLM/SenseVoiceSmall), [license](https://github.com/modelscope/FunASR/blob/main/MODEL_LICENSE)). The same third-party run puts it at 7.63% Japanese CER. Not measured.
- **kotoba-whisper v2.0** is Japanese only ([model card](https://huggingface.co/kotoba-tech/kotoba-whisper-v2.0)).
- **[WhisperKit](https://github.com/argmaxinc/WhisperKit)** runs Whisper models through Core ML. It would change the runtime, not the model.

## Not measured

- **Slower Macs and less memory**, such as an M1 with 8 GB. Everything ran on one M5 Pro with 64 GB.
- **Mixed Japanese and English in one sentence**, such as English product names inside Japanese speech.
- **Live microphone input, noise and distance.** FLEURS clips are read speech recorded close to the microphone.
- **More speakers.** All five Japanese clips are male voices, and the English clips are two male and three female. FLEURS doesn't say whether clips share a speaker.

## Sources

- [whisper.cpp README, "XCFramework"](https://github.com/ggml-org/whisper.cpp/tree/v1.9.4#xcframework): the prebuilt XCFramework is meant for Swift projects through a `binaryTarget`. Adopted as the way to ship it.
- [whisper.cpp `build-xcframework.sh` at v1.9.4](https://github.com/ggml-org/whisper.cpp/blob/v1.9.4/build-xcframework.sh): `MACOS_MIN_OS_VERSION=13.3`, so the framework runs on Mado's macOS 26.
- [whisper.cpp releases](https://github.com/ggml-org/whisper.cpp/releases): the 1.9.4 tag has no assets of its own. Build b5130 carries `whisper-b5130-xcframework.zip`, and both point at commit [`927cfce`](https://github.com/ggml-org/whisper.cpp/commit/927cfce34f31707e17f2bff35c349632fb9e2c3a). At that commit `build-xcframework.sh` sets `BUILD_SHARED_LIBS=OFF`, `GGML_METAL=ON` and `WHISPER_COREML=ON` with `WHISPER_COREML_ALLOW_FALLBACK=ON` for macOS.
- [whisper.cpp LICENSE](https://github.com/ggml-org/whisper.cpp/blob/v1.9.4/LICENSE) and [OpenAI Whisper README, "License"](https://github.com/openai/whisper#license): the library is MIT, and Whisper's code and model weights are MIT.
- [`SpeechTranscriber`](https://developer.apple.com/documentation/speech/speechtranscriber) and [`isAvailable`](https://developer.apple.com/documentation/speech/speechtranscriber/isavailable): the general-purpose model. It depends on the device's hardware, and Apple suggests DictationTranscriber where it isn't available. It takes a locale up front, with no auto-detect option in the SDK's interface.
- [`DictationTranscriber`](https://developer.apple.com/documentation/speech/dictationtranscriber): the same models as system dictation and on-device `SFSpeechRecognizer`. It is the transcriber Apple documents for custom vocabulary and contextual strings.
- [`AssetInventory`](https://developer.apple.com/documentation/speech/assetinventory): SpeechAnalyzer's models are downloaded from Apple, managed by the system and shared between apps. An app installs them per locale before use and releases them when done.
- [`AnalysisContext.contextualStrings`](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings): documented for DictationTranscriber only, up to 100 short phrases. This is why Apple's custom-word support counted against SpeechTranscriber.
- [`SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer): `prepareToAnalyze(in:)` preloads the model, and `start(inputAudioFile:finishAfterFile:)` and the `finalize…` methods end a session. These are what the measurements used. Apple's interfaces were read from the Speech framework in the Xcode 27 macOS SDK.
- [Qwen3-ASR-1.7B model card](https://huggingface.co/Qwen/Qwen3-ASR-1.7B): Apache-2.0.
- [FluidAudio Models.md](https://github.com/FluidInference/FluidAudio/blob/v0.17.5/Documentation/Models.md): Parakeet TDT v3 (0.6B, 25 European languages) and Parakeet TDT Japanese (0.6B, Japanese only) as Core ML models. Adopted as the way to run Parakeet. FluidAudio is Apache-2.0.
- [Parakeet TDT 0.6B v3 model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) and [FluidInference's Core ML conversion](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml): 25 European languages, no Japanese. CC-BY-4.0.
- [FluidInference/parakeet-0.6b-ja-coreml](https://huggingface.co/FluidInference/parakeet-0.6b-ja-coreml): a Core ML conversion of `nvidia/parakeet-tdt_ctc-0.6b-ja`. CC-BY-4.0.
- [FLEURS dataset card](https://huggingface.co/datasets/google/fleurs): the clips and reference transcripts, CC BY 4.0.

The Japanese and English accuracy ranking comes from this document's own measurements, not from published leaderboards. Third-party FLEURS results ([Handy](https://models.handy.computer/languages/ja)) were only used to pick which models to measure. Its figures for models that weren't measured have no first-party source and are marked that way above.

## How it was measured

- **Clips.** The first five distinct sentences in the [FLEURS](https://huggingface.co/datasets/google/fleurs) test archive for `ja_jp` and `en_us` (CC BY 4.0), 16 kHz mono, 4.3–14.2 s long. FLEURS sentence ids: ja1–5 = 1828, 1834, 1813, 1869, 1744; en1–5 = 1904, 1675, 1950, 1728, 1972. The FLEURS raw transcription is the reference.
- **Engines.** Each engine got the language (Japanese or English) up front. Whisper's auto-detect was checked in a separate run.
  - Apple: `SpeechAnalyzer.start(inputAudioFile:finishAfterFile:)`, with `SpeechTranscriber(preset: .transcription)` or `DictationTranscriber(preset: .shortDictation)`. A new analyzer per clip, after one `prepareToAnalyze(in:)` to load the model.
  - Whisper: `whisper-cli` from whisper.cpp 1.9.4 (Homebrew, Metal), with the default 4 threads and beam size 5. The model files are `ggml-small.bin` and `ggml-large-v3-turbo.bin`, checked against their published SHA-256.
  - Parakeet: FluidAudio 0.17.5 (commit `0b1f462`) with the default `AsrManager` config, through a small Swift program that loads the models once and transcribes each clip twice. TDT Japanese ran on the Japanese clips and TDT v3 on the English ones. Memory is from `/usr/bin/time -l` over the whole run. Time per clip is `AsrManager.transcribe` on samples already decoded.
  - Qwen3-ASR: `speech transcribe-batch` from soniqo speech-swift 0.0.28 (MLX), with `-m 0.6B-8bit` or `-m 1.7B` (8-bit weights from `aufklarer/Qwen3-ASR-*-MLX-8bit`).
- **Time.** Each run was done twice and the second kept. Time per clip leaves out model load, and model load leaves out the download.
- **Memory.** Whisper and Qwen3: peak RSS and peak memory footprint from `/usr/bin/time -l`. Apple: the lifetime peak footprint (`ri_lifetime_max_phys_footprint` from `proc_pid_rusage`) of the `localspeechrecognition` process that served the run, read while the client was still connected. Each Apple figure was the same on two runs, give or take 2 MB.
- **Scoring.** Both texts are NFKC-normalised and lowercased, and punctuation is removed. Japanese also drops spaces and is compared by character. English is compared by word.
- **Sample size.** One character is 0.4 points of Japanese CER (250 characters) and one word is about 1 point of English WER (103 words), so differences under a couple of points are noise. FLEURS writes "25 to 30 year" in en1 where all six engines heard "years", so every engine loses that word.
