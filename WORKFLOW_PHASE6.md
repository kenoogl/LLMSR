# LLMSR Workflow (Phase 6: Physics-Informed & Reason-Driven Evolution)

## 1. 概要
Phase 6 では、Phase 5 の進化フレームワークを拡張し、**「物理的妥当性」**と**「推論（Reason）の質」**を明示的に評価関数に組み込みます。
単にデータにフィットするだけでなく、物理的に意味のある構造と、それを裏付ける論理的な説明を持つモデルの発見を目指します。

### 主な変更点
- **評価関数**: $Score = MSE \times (1 + Penalty_{Physics}) \times (1 - 0.2 \times Score_{Reason})$
    - **Physics Penalty**: P1〜P4 の物理制約違反に基づくペナルティ。
    - **Reason Score**: LLMの生成した `reason` の質（0.0〜1.0）。良い説明には最大20%のスコアボーナスを与える。
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

1.  **初期フィードバック生成**:
    ```bash
    # seeds.json を使用する場合 (デフォルト)
    julia --project=. run_phase6.jl --generate-initial --exp-name trial_phase6_01

    # seeds.json を使用せず、完全にゼロから始める場合
    julia --project=. run_phase6.jl --generate-initial --exp-name trial_phase6_01 --seeds-file NO_SEEDS
    ```
2.  **シミュレーション実行 (Gen 1)**:
    `simulate_llm_evolution.jl` を使用して、初期集団の生成と評価を行います。
    ```bash
    julia --project=. simulate_llm_evolution.jl --start 1 --end 1 --exp-name trial_phase6_01
    ```

### Step 2: 進化と淘汰 (Generation 2+)
前世代の評価結果を元に、LLM（シミュレータ）が新しいモデルを生成し、評価するサイクルを繰り返します。

**実行コマンド**:
```bash
# 例: Gen 2 から Gen 10 までを一気に実行
julia --project=. simulate_llm_evolution.jl --start 2 --end 10 --exp-name trial_phase6_01
```

**内部プロセス (自動化されています)**:
1.  **コンテキスト構築**: 前世代のベストモデル、ペナルティ、Reasonスコアを読み込み。
2.  **モデル生成**: 物理制約を満たすよう変異・改良。
3.  **評価と保存**: `models_genX.json` を保存し、`run_phase6.jl` で評価を実行。

### Step 2: 進化と淘汰 (Generation 2+)
シミュレーションスクリプトにより自動化されていますが、論理的なステップは以下の通りです：

1.  **コンテキスト構築**:
    - 前世代のベストモデル（Top 3-5）
    - **ペナルティ内訳 (P1-P4)**: どの物理制約に違反したか。
    - **Reasonスコア**: 説明の質。
2.  **LLMへの指示 (Simulation)**:
    - 物理制約（P1-P4）を満たすように修正。
    - Reason に「どのペナルティを修正したか」を明記させる。
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
以下の項目に違反した場合、重み付きペナルティを加算します。

- **P1: x方向減衰 ($\lambda_1=1.0$)**:
  - $x$ の増加に伴い $\Delta U$ が単調減少すること（再加速しない）。
  - 無限遠 ($x \to \infty, r \to \infty$) でゼロに収束すること。
- **P2: r方向対称性 ($\lambda_2=0.5$)**:
  - $r$ と $-r$ で値が一致すること。
- **P3: 物理的範囲 ($\lambda_3=2.0$)**:
  - $0 \le \Delta U \le 1.2$ の範囲に収まること（負値や過大な値を禁止）。
- **P4: 渦粘性整合 ($\lambda_4=0.2$)**:
  - $\nu_t$ が増加した際、ピーク欠損が減少し、後流が広がる傾向にあること。

### 4.2 Reason スコア (Reason Score)
LLMの `reason` フィールドをテキスト解析します。

- **加点**:
  - 物理キーワード（turbulence, viscosity, asymptotic, etc.）の使用。
  - **ペナルティ意識**: `P1`, `P2`, `penalty` などの単語を含み、改善意図が明確であること。
- **減点**: 曖昧な表現（adjusted, tweaked, random guess）。
- **スコア範囲**: 0.1 (Bad) 〜 1.0 (Good)。

---

## 5. 分析・評価ツール (Analysis & Evaluation Tools)

### 5.1 ベースラインのキャリブレーション (Calibration)

評価の一貫性を保つため、標準モデル（Jensen, Bastankhah）の最適係数を事前に厳密に計算し、固定します。

**使用方法**:
```bash
julia --project=. calibrate_baselines.jl
```
- 入力データ（`data/result_I0p3000_C22p0000.csv`）に対応する設定ファイル `params/standard_models_result_I0p3000_C22p0000.json` が生成されます。
- このファイルが存在する場合、以下のツールは自動的にこれを読み込みます。

### 5.2 モデルの詳細分析 (Inspection)

特定の世代の特定のモデルを個別に可視化し、CFDデータと比較します。

**使用方法**:
```bash
# 特定の世代の最良モデルを描画 (例: Gen 20)
julia --project=. inspect_model.jl --gen 20 --best --exp-name trial_8

# 特定の世代の特定IDのモデルを描画 (例: Gen 7, ID 3)
julia --project=. inspect_model.jl --gen 7 --id 3 --exp-name trial_8
```

### 5.3 ベンチマークと最終評価 (Benchmarking)

発見された最良モデルを、標準的な後流モデルと厳密に比較します。

**使用方法**:
```bash
julia --project=. benchmark_models.jl --exp-name trial_8 --gen 20
```
- **出力**: `results/{exp_name}/plots/benchmark_summary.txt` に詳細な比較結果が出力されます。

### 5.4 進化系統の追跡 (Lineage Tracing)

最良モデルがどのように進化してきたか、その系譜を可視化します。

**使用方法**:
```bash
julia --project=. trace_evolution_lineage.jl --exp-name trial_8
```
- **出力**: `results/{exp_name}/evolution_lineage.md` (Mermaidグラフ付きレポート)

### 5.5 ReasonとMSEの相関分析 (Reason-MSE Correlation)

LLMが生成した「Reason（説明）」の質（Reason Score）と、実際のモデル性能（MSE）に相関があるかを分析します。

**使用方法**:
```bash
julia --project=. analyze_reason_correlation.jl --exp-name trial_8
```
- **出力**:
    - `results/{exp_name}/plots/reason_vs_mse_scatter.png`: 散布図
    - `results/{exp_name}/plots/reason_vs_mse_dist.png`: スコアごとの分布図
    - コンソールに相関係数と統計情報を表示。

### 5.6 物理的妥当性の推移分析 (Physics Validity Trend)

物理制約を完全に満たしている（ペナルティ合計が0）モデルの割合が、世代ごとにどう推移しているかを可視化します。

**使用方法**:
```bash
julia --project=. analyze_physics_validity.jl --exp-name trial_8
```
- **出力**:
    - `results/{exp_name}/plots/physics_validity_trend.png`: 推移グラフ
    - コンソールに開始・終了時の妥当性割合と変化ポイントを表示。

---

## 6. トラブルシューティング

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
