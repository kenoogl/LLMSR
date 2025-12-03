# LLMSR Workflow (Phase 6: Physics-Informed & Reason-Driven Evolution)

## 1. 概要
Phase 6 では、Phase 5 の進化フレームワークを拡張し、**「物理的妥当性」**と**「推論（Reason）の質」**を明示的に評価関数に組み込みます。
単にデータにフィットするだけでなく、物理的に意味のある構造と、それを裏付ける論理的な説明を持つモデルの発見を目指します。

### 主な変更点
- **評価関数**: $Score = MSE \times (1 + Penalty_{Physics}) \times (1 - 0.2 \times Score_{Reason})$
    - **Physics Penalty**: P1〜P4 の物理制約違反に基づくペナルティ。
    - **Reason Score**: LLMの生成した `reason` の質（0.0〜1.0）。
        - **デフォルト**: ルールベース評価 (`ReasonScorer.jl`)。
        - **拡張**: APIベースの3段階評価 (`evaluate_reason_api.jl`)。
- **モジュール構成**: `src/Phase6/` 下に機能を分割（Physics, ReasonScorer, Evaluator, Optimizer）。

---

## 2. 準備

### 環境設定
```bash
# Julia プロジェクトの有効化
julia --project=.
```

### 必要なファイル
- `run_phase6.jl`: メイン実行スクリプト
- `simulate_llm_evolution.jl`: 進化シミュレーションスクリプト
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

**内部プロセス (自動化)**:
1.  **コンテキスト構築**: 前世代のベストモデル、ペナルティ(P1-P4)、Reasonスコアを読み込み。
2.  **モデル生成**: 物理制約を満たすよう変異・改良。
3.  **評価と保存**: `run_phase6.jl` が呼び出され、MSEとペナルティを計算。

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
```bash
julia --project=. calibrate_baselines.jl
```

### 5.2 モデルの詳細分析 (Inspection)
特定の世代の特定のモデルを個別に可視化し、CFDデータと比較します。
```bash
julia --project=. inspect_model.jl --gen 20 --best --exp-name trial_8
```

### 5.3 ベンチマークと最終評価 (Benchmarking)
発見された最良モデルを、標準的な後流モデルと厳密に比較します。
```bash
julia --project=. benchmark_models.jl --exp-name trial_8 --gen 20
```

### 5.4 進化系統の追跡 (Lineage Tracing)
最良モデルがどのように進化してきたか、その系譜を可視化します。
```bash
julia --project=. trace_evolution_lineage.jl --exp-name trial_8
```

### 5.5 ReasonとMSEの相関分析 (Reason-MSE Correlation)
LLMが生成した「Reason（説明）」の質（Reason Score）と、実際のモデル性能（MSE）に相関があるかを分析します。
```bash
julia --project=. analyze_reason_correlation.jl --exp-name trial_8
```

### 5.6 APIによるReasonの精密評価 (Advanced API Evaluation)
LLM (Gemini 1.5 Pro等) を使用して、Reasonの質を「専門家」の視点で厳密に評価します。
**3段階チェーン評価**（論理抽出 -> 物理検証 -> スコアリング）を行い、ルールベース評価よりも高精度な判定を行います。

**準備**:
1. `templates/` 配下のプロンプトファイル (`system_prompt.md`, `task_step1.txt` 等) が必要です。
2. 環境変数 `GOOGLE_API_KEY` を設定してください。

**使用方法**:
```bash
export GOOGLE_API_KEY="AIza..."
julia --project=. evaluate_reason_api.jl --gen 20 --exp-name trial_8 --model gemini-1.5-pro-latest
```

### 5.7 評価精度の検証 (Verification of Evaluation Quality)
新しく導入したAPI評価が、従来のルールベース評価よりも優れているか（MSEとの相関が高いか）を検証します。
```bash
julia --project=. compare_reason_scores.jl
```
- **出力**: 新旧スコアの相関係数比較、散布図、分布図。

### 5.8 物理的妥当性の推移分析 (Physics Validity Trend)
物理制約を完全に満たしている（ペナルティ合計が0）モデルの割合が、世代ごとにどう推移しているかを可視化します。
```bash
julia --project=. analyze_physics_validity.jl --exp-name trial_8
```

---

## 6. トライアル終了後の処理
1.  **結果のアーカイブ**: `results/trial_X/`
2.  **Seeds更新**: 物理的に妥当なベストモデルを `seeds.json` に追加。
3.  **レポート作成**: 物理的妥当性の検証結果を含める。
