# 半自動進化計算ワークフロー

このガイドでは、Gemini LLMとJuliaを使った半自動進化計算の実行手順を説明します。

## 🎯 概要

**役割分担**:
- **Julia**: モデルの評価、係数最適化、結果の保存
- **Gemini LLM**: 構造式の生成、進化戦略の適用
- **ユーザー**: 両者の橋渡し（JSONファイルの受け渡し）

**データフロー**:
```
Julia → feedback_genN.json → ユーザー → Gemini
Gemini → models_genN+1.json → ユーザー → Julia
```

---

## 📋 実行手順

### ステップ0: 準備

```bash
# プロジェクトディレクトリに移動
cd /Users/Daily/Development/WindTurbineWake/LLMSR

# 依存パッケージの確認
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# 動作確認（オプション）
julia --project=. main.jl
```

---

### ステップ1: 初期集団の生成（世代0）

```bash
julia --project=. semi_auto_evolution.jl --generate-initial --size 20
```

**出力**:
- `results/feedback_gen0.json` が生成される
- このファイルには、Geminiへの指示が含まれている

**内容確認**:
```bash
cat results/feedback_gen0.json | jq
```

---

### ステップ2: Geminiに初期集団を生成させる

1. **feedback_gen0.json の内容をGeminiに提示**

チャットで以下のように依頼：

```
results/feedback_gen0.json を見て、
風車後流モデルの構造式を20個生成してください。

指示に従って、多様性のある式を生成してください。
出力は以下のJSON形式でお願いします：

{
  "generation": 1,
  "models": [
    {
      "id": 1,
      "formula": "a * exp(-b*x) * exp(-c*r^2)",
      "num_coeffs": 3,
      "reason": "...",
      "ep_type": "EP1"
    },
    ...
  ]
}
```

2. **Geminiの応答をファイルに保存**

Geminiが生成したJSONを `results/models_gen1.json` に保存

---

### ステップ3: 世代1の評価

```bash
julia --project=. semi_auto_evolution.jl --evaluate 1 --input results/models_gen1.json
```

**処理内容**:
- 20個のモデルをそれぞれ評価（DEで係数最適化）
- スコア（MSE）を計算
- 結果を `results/feedback_gen1.json` に保存
- 履歴を `results/history.jsonl` に追記

**出力例**:
```
🔬 Evaluating Generation 1
====================================================================

📂 Loading models from: results/models_gen1.json
   ✓ Loaded 20 models

⚙️  Evaluating models...
   [ 1/20] a * exp(-b*x) * exp(-c*r^2)...              ✓ Score: 0.001234
   [ 2/20] a * x^(-b) * (1 + c*r^2)^(-d)...            ✓ Score: 0.002145
   ...

📊 Generation 1 Statistics
====================================================================
   Population size: 20
   Best score:      0.001234
   Median score:    0.003456
   Mean score:      0.004123
   Worst score:     0.012345

🏆 Top 3 Models:
----------------------------------------------------------------------
[1] Score: 0.001234
    Formula: a * exp(-b*x) * exp(-c*r^2)
    Coeffs: [0.92, 0.028, 1.35]
    Reason: Classic Gaussian profile
...
```

---

### ステップ4: 世代2以降の繰り返し

**4-1. feedback_gen1.json を Geminiに提示**

```
results/feedback_gen1.json を見て、次世代（世代2）の
構造式を20個生成してください。

前世代の結果を参考に、以下の戦略で生成してください：
- EP1（多様性）: 4個 - 全く新しい構造
- EP2（局所改善）: 10個 - ベストモデルの改良
- EP3（物理性改善）: 4個 - 物理的制約を満たすよう修正
- EP4（簡素化）: 2個 - 複雑なモデルを簡素化

【重要な観察】
- ベストモデル: a * exp(-b*x) * exp(-c*r^2) (Score: 0.001234)
- このモデルは古典的なGaussianプロファイルです
- 乱流項（k, omega, nut）を含むモデルは試されていません
- べき乗型のモデルはGaussian型より精度が低い傾向

出力は同じJSON形式でお願いします。
```

**4-2. Geminiの応答を保存**

`results/models_gen2.json` に保存

**4-3. 評価実行**

```bash
julia --project=. semi_auto_evolution.jl --evaluate 2 --input results/models_gen2.json
```

**4-4. これを世代20まで繰り返す**

---

### ステップ5: 進化の可視化

任意の時点で、これまでの進化の様子を確認できます：

```bash
julia --project=. visualize_evolution.jl
```

**出力**:
- `results/plots/evolution_curve.png` - 世代ごとのスコア推移
- `results/plots/score_distribution.png` - スコア分布の箱ひげ図
- `results/plots/evolution_summary.txt` - テキストサマリー

**サマリーの表示**:
```bash
cat results/plots/evolution_summary.txt
```

---

## 💡 効率的な実行のコツ

### 1. フィードバックの読み方

`feedback_genN.json` の重要なポイント：

```json
{
  "best_model": {
    "formula": "...",  // ← これまでで最良の式
    "score": 0.001234  // ← 達成スコア
  },
  "evaluated_models": [
    {
      "formula": "...",
      "score": ...,
      "reason": "...",   // ← なぜこの式を生成したか
      "ep_type": "EP2"   // ← どの戦略で生成したか
    }
  ]
}
```

### 2. Geminiへの効果的なプロンプト

**初期世代（1-5）**: 多様性重視
```
EP1とEP2を中心に、様々なアプローチを試してください。
乱流項、べき乗型、Gaussian型、複合型など。
```

**中期世代（6-15）**: 局所改善 + 物理性
```
ベストモデルを基に改良してください（EP2）。
物理的制約（x減衰、r対称性）を確認してください（EP3）。
```

**後期世代（16-20）**: 精緻化 + 簡素化
```
微調整で精度を詰めてください（EP2）。
過剰に複雑なモデルは簡素化してください（EP4）。
```

### 3. 中断と再開

途中で中断しても問題ありません：

- `results/history.jsonl` に全履歴が保存されている
- 次回は直前の世代のfeedbackからGeminiに依頼
- 世代番号を合わせて評価を再開

### 4. パラメータ調整

集団サイズを変更したい場合：

```bash
# 初期集団を10個に変更
julia --project=. semi_auto_evolution.jl --generate-initial --size 10

# 以降も10個ずつ生成してもらう
```

---

## 📊 進化の評価指標

### スコア改善率

世代1と世代Nのベストスコアを比較：

```julia
improvement = (score_gen1 - score_genN) / score_gen1 * 100
```

目標: **50%以上の改善**（例: 0.01 → 0.005）

### 多様性

各世代でユニークな式のパターン数をチェック。
多様性が低下しすぎたら、EP1を増やす。

### 物理性

非物理的なモデル（xで発散、負のΔUなど）が生成されている場合は、
EP3で修正を依頼。

---

## 🐛 トラブルシューティング

### エラー: "Model file not found"

→ `results/models_genN.json` のファイル名が正しいか確認

### エラー: "All models failed evaluation"

→ 生成された式に構文エラーがある可能性
→ JSON形式が正しいか確認（`jq` で検証）

### スコアが改善しない

→ Geminiへのフィードバックを詳しくする
→ EP2（局所改善）の比率を上げる
→ 物理的ヒントを追加（「乱流項を入れてみてください」など）

### 式が複雑すぎる

→ EP4（簡素化）を依頼
→ 係数数の上限を設定（例: 5個まで）

---

## ✅ チェックリスト（20世代完走）

- [ ] 世代0: 初期フィードバック生成
- [ ] 世代1-5: 多様性探索
- [ ] 世代6-10: 有望な方向性の改善
- [ ] 世代11-15: 物理性とバランスの調整
- [ ] 世代16-20: 精緻化と簡素化
- [ ] 可視化実行
- [ ] 最良モデルの検証
- [ ] 結果のまとめ

---

## 📁 ファイル構成

実行後のディレクトリ構造：

```
LLMSR/
├── results/
│   ├── feedback_gen0.json
│   ├── models_gen1.json
│   ├── feedback_gen1.json
│   ├── models_gen2.json
│   ├── ...
│   ├── models_gen20.json
│   ├── feedback_gen20.json
│   ├── history.jsonl           # 完全な履歴
│   └── plots/
│       ├── evolution_curve.png
│       ├── score_distribution.png
│       └── evolution_summary.txt
```

---

## 🎓 次のステップ

20世代完了後：

1. **最良モデルの詳細検証**
   - 予測値 vs 実測値のプロット
   - 物理的解釈の検討

2. **既存モデルとの比較**
   - Jensen, Bastankhah, Gaussian モデルとのベンチマーク

3. **論文執筆**
   - 進化の過程を可視化
   - LLMが生成したReasonの分析
   - 物理的洞察の抽出

4. **他のLLMとの比較**
   - GPT-4o, Claude でも同じ実験
   - 結果の比較分析
