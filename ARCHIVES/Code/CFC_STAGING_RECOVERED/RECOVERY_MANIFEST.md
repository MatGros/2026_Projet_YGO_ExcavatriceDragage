# Recovery manifest — CFC staging artifacts

## Scope

Archived recovery only. No file under active `CODE/`, `TOOLS/`, or `DOC/` was changed by this recovery.
Each payload was recovered from the cited `*worker*transcript.jsonl` tool-call argument/history.
Where a historical tool call wrote a file through an embedded Python script, that recorded script was replayed with **only its output path redirected** to this archive; its historical content and transformations were not redesigned or regenerated.

## Restored files

| Restored relative path | Source transcript(s) | SHA256 |
|---|---|---|
| `CODE/COMMUN/FB_ResetAggregation.st` | `6ae6b016_worker_0_transcript.jsonl` | `3e19c96ddfc1ddd72cf9b340fda62b6a7369f52e81ba5f5542891e4de3d19670` |
| `CODE/COMMUN/ST_ResetCommand.st` | `6ae6b016_worker_0_transcript.jsonl` | `b167fc8933b1c17d0b6d5f308a00dd22faf7feb4752f0889e1b9d55f7d53bc99` |
| `CODE/CYCLE/FB_CycleIhmBridge.st` | `ce2c5a54_worker_0_transcript.jsonl` | `7b5cf9a4bb4a4a4e9dc47d46af676dd13d1b28c365ed680fa90bbeb1f4b4f343` |
| `CODE/MAIN/PRG_02_Acquisition_Staging_CFC.xml` | `6ae6b016_worker_0_transcript.jsonl; 2c96686e_worker_0_transcript.jsonl` | `432549d1cf927568629c2717a3e272f7fdc1308dc3e83fa9ed08e0e2fc93252a` |
| `CODE/MAIN/PRG_03_Modes_Cycle_CFC.xml` | `ce2c5a54_worker_0_transcript.jsonl; 2c96686e_worker_0_transcript.jsonl` | `a67c2f6134ab6c618080035bd64a2686d751df51ce12512312cc60dda1b99c86` |
| `CODE/MAIN/PRG_04_Treuils_Benne_CFC.xml` | `2c96686e_worker_0_transcript.jsonl` | `02cb64fda8e174d9927f69b55abc89238e63ab64a23b7a9840d6dd71913a4932` |
| `CODE/MAIN/PRG_05_Translation_CFC.xml` | `ae12cfc5_worker_0_transcript.jsonl; 2c96686e_worker_0_transcript.jsonl` | `d3af21997dd61c3dedcd9d66c98a84f4f72316a1ab4f063068bc36930d68c642` |
| `CODE/MAIN/PRG_06_Outputs_Staging_LD.st` | `550f2c0a_worker_0_transcript.jsonl` | `e5f6f26f83d1ffb36fac9ab5bc6338855f43442f6dcbf51d19ff0adb962e7421` |
| `CODE/MAIN/PRG_07_Supervision_CFC.xml` | `ff473a43_worker_0_transcript.jsonl; 2c96686e_worker_0_transcript.jsonl` | `9759b219de1ba65d6225949bf8958a0a359b3218d8e0c22891b42154a6a62f22` |
| `CODE/SIMULATION/FB_AcquisitionRouter.st` | `6ae6b016_worker_0_transcript.jsonl` | `93c01e84f2255771e171282e20112c447fbafc7b77f0484d47506399aa8d6703` |
| `CODE/SUPERVISION/FB_SupervisionProjection.st` | `ff473a43_worker_0_transcript.jsonl` | `64ece62728e0f3ecbe94e3514c61d49ceb57408b31cba564c78d9c38dfea5b10` |
| `CODE/TRANSLATION/FB_TranslationArbiter.st` | `ae12cfc5_worker_0_transcript.jsonl` | `9df823c876f8d8fae20a9f1e9279ef546f11a82438bd21da7cbeb6be7b0d7cfc` |
| `CODE/TRANSLATION/FB_TranslationCfcExpressions.st` | `2c96686e_worker_0_transcript.jsonl` | `23f1529526e58036ec7b5e769785f8d03c1f9db4c5727c772ebaf65ef4fe308e` |
| `CODE/TRANSLATION/FB_TranslationFeedbackMemory.st` | `ae12cfc5_worker_0_transcript.jsonl` | `79e7f1a85f7ef5a3abd893107a088ac895b867b5037c321d36428a236cef6eeb` |
| `CODE/TRANSLATION/FB_TranslationRequestPublisher.st` | `ae12cfc5_worker_0_transcript.jsonl` | `0b540ab9e56be58d95878c9a64adf880feaa7c0c21f4d1e645c0295ae99358a8` |
| `CODE/TRANSLATION/FB_TranslationRuntimeGate.st` | `ae12cfc5_worker_0_transcript.jsonl` | `70760ecf8a6d318f26e0bb149584c0ebcb15c457e141abe0379916bb3d815109` |
| `CODE/TREUILS/FB_TreuilsBenneStagingProjection.st` | `2c96686e_worker_0_transcript.jsonl` | `8f6965063508357d20e9736e5ad54593775633ebd2b62e882ea4405b73aa8f9c` |
| `TOOLS/AGENT_WORKFLOW/tests/test_check_cfc_wiring_staging.py` | `2c96686e_worker_0_transcript.jsonl` | `8b90f69b64be902d4f61be573ddd987d93bdcc27f47ec6f6ea0639382e7abb94` |
| `TOOLS/AGENT_WORKFLOW/tests/test_prg04_treuils_benne_cfc.py` | `d5ffdadb_worker_0_transcript.jsonl` | `f3063b9d5282fde5b6b537bb69bbd463e0a2988ec9217f5c80bcca122963fc53` |
| `TOOLS/AGENT_WORKFLOW/tests/test_prg05_translation_cfc.py` | `ae12cfc5_worker_0_transcript.jsonl` | `c888d3cbf7f20645b034217fb73a96e93d66d4f397323b5ed0167c2f374a7ebf` |
| `TOOLS/AGENT_WORKFLOW/tests/test_prg06_outputs_staging.py` | `550f2c0a_worker_0_transcript.jsonl` | `8a5de9e884a33907e662270c2e51a0a24132abb1390f8f2a4a4c0e52f32c03eb` |

## Verbatim recovery exceptions

None identified. Every deleted staging XML/ST/test artifact found in the worker transcript history was restored.

## Registry sections

No registry write was made: the existing active registry already contains the M1, M2, M3, M4, M5, M6, and M8 staging sections (including A-08, A-13, A-14, and A-15).

## Validation performed

- XML parse: all five archived staging XML files parse with `xml.etree.ElementTree`.
- Archive inventory: 21 staging XML/ST/test files restored.
- Git index: no staged files.
