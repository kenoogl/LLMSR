# Trial 4 Final Report: Phased Evolutionary Search

## Executive Summary

Trial 4 implemented a **phased evolutionary strategy** to discover wake models, separating structural exploration (Gen 0-15) from fine-tuning (Gen 16-20).

*   **Best Model Found**: Generation 4, ID 10
*   **Best Score (MSE)**: **0.000455**
*   **Baseline (Jensen)**: 0.000480
*   **Improvement**: ~5.2% over Jensen

Contrary to expectations, the **Offset Tuning (EP5)** phase in Generations 16-20 did *not* improve upon the best structural model found in the early exploration phase. The best performance was achieved by a pure structural modification in Generation 4, highlighting the importance of the core decay formulation over additive corrections for this dataset.

## Best Model Details

**Formula**:
```math
u_{def} = a \cdot (1 + b \cdot \sqrt{x})^{-2.5} \cdot (1 + c \cdot r^2 + d \cdot r^4)^{-1} \cdot (1 + e \cdot x)
```

**Coefficients**:
```julia
[81.8311, 53.4407, 3.4980, 4.0883, 78.0886]
```

**Key Features**:
1.  **$\sqrt{x}$ Decay**: Uses `sqrt(x)` as the scaling variable instead of linear `x`.
2.  **Higher Decay Power**: The exponent is `-2.5` (vs standard `-2`), indicating a faster initial decay that slows down differently than the standard inverse square law.
3.  **Polynomial Radial Profile**: Uses `(1 + cr^2 + dr^4)^-1`, allowing for a more complex radial shape (likely flatter top or different tail) than a simple Gaussian.
4.  **Linear Correction**: The `(1 + ex)` term acts as a global scaling factor that evolves linearly downstream.

## Evolutionary Dynamics Analysis

### Phase 1: Exploration (Gen 0-15)
*   **Rapid Discovery**: The best model was found very early (Gen 4).
*   **Structural Diversity**: The strategy successfully explored various decay forms (`x`, `sqrt(x)`, `exp(x)`). The `sqrt(x)` branch consistently outperformed others.
*   **Physical Parameters**: Integration of `k` (TKE), `nut` (Eddy Viscosity), and `omega` in Gen 6-15 yielded interesting models but none surpassed the pure geometric `sqrt(x)` model. This suggests that for this specific dataset (LES data), the geometric constraints are more dominant than the available local physical parameters for predicting velocity deficit.

### Phase 2: Fine-tuning (Gen 16-20)
*   **Strategy**: EP5 (Offset Tuning) was introduced to add additive terms (`+ offset`) to the best structures.
*   **Outcome**: This phase failed to improve the score. The best offset model achieved ~0.00099, significantly worse than the Gen 4 structural model (0.000455).
*   **Analysis**: The additive offsets likely introduced overfitting or unphysical biases that the MSE metric penalized on the validation set (or the optimization landscape became too complex/flat for DE to solve efficiently). The "constant offset" hypothesis (that a simple bias correction would fix the remaining error) was proven incorrect for this physics-driven problem.

## Comparison with Baselines

| Model | MSE Score | Notes |
|-------|-----------|-------|
| **Trial 4 Best (Gen 4)** | **0.000455** | **Sqrt(x) decay + Poly(r)** |
| Jensen (Baseline) | 0.000480 | Standard industry model |
| Gaussian (Baseline) | 0.001553 | Standard Gaussian profile |
| Trial 3 Best | 0.000116 | (Previous best, likely overfit or different split?) |

*Note: The Trial 3 best score (0.000116) was significantly lower. Trial 4's inability to replicate this suggests either:*
1.  *Trial 3 found a "unicorn" structure that Trial 4 missed.*
2.  *Trial 3's score was an outlier or benefited from a specific random seed/initialization.*
3.  *The `sqrt(x)` branch, while robust, hit a local optimum that is higher than Trial 3's best.*

## Conclusion & Recommendations

Trial 4 demonstrated that **structural innovation** (changing the decay law to `sqrt(x)`) is more effective than **additive corrections** (offsets) or **complex physical parameter couplings** for this specific wake modeling task.

**Future Directions**:
1.  **Revisit Trial 3**: Analyze the Trial 3 best model structure again. If it was truly superior, we should seed Trial 5 with it.
2.  **Hybrid Decay**: Combine `x` and `sqrt(x)` decay terms more explicitly.
3.  **Multi-Objective**: The single MSE metric might be hiding trade-offs. Future trials could consider near-wake vs. far-wake accuracy separately.
