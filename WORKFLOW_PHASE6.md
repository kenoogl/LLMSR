# LLMSR Workflow (Phase 6: Physics-Informed & Reason-Driven Evolution)

## 1. 概要
Phase 6 では、Phase 5 の進化フレームワークを拡張し、**「物理的妥当性」**と**「推論（Reason）の質」**を明示的に評価関数に組み込みます。
単にデータにフィットするだけでなく、物理的に意味のある構造と、それを裏付ける論理的な説明を持つモデルの発見を目指します。

### 主な変更点
- **評価関数**: $Score = MSE \times (1 + Penalty_{Physics}) \times (1 - Score_{Reason})$
    - **Physics Penalty**: 減衰、対称性、非負性などの物理制約違反にペナルティ。
    - **Reason Score**: LLMの生成した `reason` の質（物理用語の使用、具体性）に応じてスコアを割引（良ければスコアが良くなる）。
- **モジュール構成**: `src/Phase6/` 下に機能を分割（Physics, ReasonScorer, Evaluator, Optimizer）。

---

## 2. 準備

### 環境設定
```bash
# Julia プロジェクトの有効化
julia --project=.
```

### 必要なファイル
- `run_phase6.jl`: 実行スクリプト
- `templates/phase6_prompt.md`: プロンプトテンプレート
- `seeds.json`: 初期シード（Trial 7までのベストモデルを含む）

---

## 3. 実行サイクル (Evolution Loop)

### Step 1: 初期集団の生成 (Generation 1)
`seeds.json` のモデルと、LLMによる新規生成モデルを組み合わせて初期集団を作ります。

1.  **プロンプト作成**: `templates/phase6_prompt.md` を使用。
2.  **LLM生成**: Gemini 1.5 Pro 等を使用。
3.  **評価**: `run_phase6.jl` を使用して評価。
    - `models_gen1.json` を保存。
    - `feedback_gen1.json` を生成（Reasonスコアを含む）。

### Step 2: 進化と淘汰 (Generation 2+)
前世代の `feedback_genX.json` を元に、LLMに次の世代を生成させます。

1.  **コンテキスト構築**:
    - 前世代のベストモデル（Top 3-5）
    - 物理ペナルティの状況（「このモデルは物理的に正しい/正しくない」）
    - Reasonの評価（「説明が具体的で良い/曖昧で悪い」）
2.  **LLMへの指示**:
    - 物理制約を満たすように修正。
    - Reason をより物理的・具体的に記述するように指示。
3.  **評価と保存**:
    - `models_genX.json` -> `feedback_genX.json`

### Step 3: 分析と選定
各世代の終了時、またはトライアル終了時に分析を行います。

- **トレードオフ分析**: MSE vs Physics Penalty vs Reason Score の関係を確認。
- **ベストモデル選定**:
    - 優先順位: 物理ペナルティ $\approx 0$ > MSE が低い > Reason が良い。

---

## 4. 評価基準の詳細

### 4.1 物理ペナルティ (Physics Penalty)
以下の項目に違反した場合、ペナルティを加算します。
1.  **非負性**: $\Delta U < 0$ となる領域があるか。
2.  **単調減衰**: 下流に行くほど $\Delta U$ が減少するか（回復するか）。
3.  **対称性**: 半径方向 $r$ に対して対称か（偶関数的か）。
4.  **漸近挙動**: $x \to \infty, r \to \infty$ で $\Delta U \to 0$ となるか。

### 4.2 Reason スコア (Reason Score)
LLMの `reason` フィールドをテキスト解析します。
- **加点**: 物理用語（turbulence, viscosity, momentum, etc.）の使用。
- **減点**: 曖昧な表現（adjusted, tweaked, random guess）。
- **スコア範囲**: 0.0 (Bad) 〜 1.0 (Good)。
- **反映**: 最終スコアを $(1 - 0.1 \times Score_{Reason})$ 倍するなどして優遇。

---

## 5. トラブルシューティング

### ペナルティが減らない場合
- プロンプトで物理制約の重要性を強調する。
- 具体的な違反箇所（例：「遠方で再加速している」）をフィードバックに含める。

### Reason が定型的になる場合
- 「なぜその項を追加したのか」「物理的にどういう意味があるのか」を問うプロンプトに切り替える。

---

## 6. トライアル終了後の処理
1.  **結果のアーカイブ**: `results/trial_X/`
2.  **Seeds更新**: 物理的に妥当なベストモデルを `seeds.json` に追加。
3.  **レポート作成**: 物理的妥当性の検証結果を含める。
