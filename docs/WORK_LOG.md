# Work log

- Inspected the clean repository: only README, ignore rules and the original MIT license; no applicable AGENTS.md found. Preserved the 2019 author notice.
- Applied ub-mode: first wrote host behavior tests and observed the missing implementation fail; then implemented a hardware-independent command parser and motor model. Host tests pass under AddressSanitizer/UBSan.
- Chose Uno Rev3, HC-05 Classic SPP and TB6612FNG; isolated pin output from protocol logic. Motor enable starts low; invalid input and command expiry disable it.
- Generated an Android-only Flutter project using installed stable Flutter 3.41.9 / Dart 3.11.5. No connected hardware will be operated.
