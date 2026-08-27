---
name: ai-accuracy-evaluation
description: Design, run, or review evaluations for OCR, document extraction, similarity search, retrieval, classification, recommendation, and LLM-assisted pipelines. Use when the user asks about accuracy, validation data, thresholds, regressions, false positives, or quality improvement.
---

# AI Accuracy Evaluation

Make quality claims reproducible, segmented, and useful for deciding what to improve next.

## Define the evaluation before optimizing

- State the unit of evaluation, target behavior, ground truth source, inclusion and exclusion rules, dataset version, and success criteria.
- Separate development, validation, and final test data. Detect duplicate or near-duplicate documents, shared templates, entities, or time periods that could leak across splits.
- Preserve raw predictions and provenance so every aggregate result can be traced to an individual example.
- Establish a baseline and record the exact model, prompt, index, preprocessing, code revision, parameters, threshold, and runtime environment.

## Measure what matters

- Choose metrics that match the decision: precision, recall, F-score, exact or field match, character or word error rate, ranking metrics, calibration, latency, and cost as appropriate.
- Report denominators and confidence or uncertainty, not percentages alone.
- Slice results by meaningful source, document type, category, field, language, image quality, time period, or difficulty. Include small-sample warnings.
- Inspect false positives, false negatives, abstentions, and high-confidence errors. Create a compact error taxonomy with representative examples.
- For threshold selection, show the precision-recall or business-cost tradeoff and choose the threshold on validation data rather than the final test set.

## Compare and improve safely

- Compare candidates on the same frozen examples and evaluation code. Attribute improvements separately when several pipeline components change.
- Check whether the apparent gain comes from exclusions, fallback behavior, manual correction, cached results, or data leakage.
- Turn dominant error groups into prioritized hypotheses and targeted experiments. Avoid broad tuning that only fits a few observed examples.
- Save machine-readable results plus a human-readable summary containing method, metrics, slices, regressions, limitations, and the next recommended experiment.
