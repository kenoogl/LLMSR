# Model Evolution Lineage

## Evolution Path from Generation 1 to 20

This document traces the evolutionary path of the champion model,
showing how the mathematical structure evolved across generations.

## Major Milestones

### Generation 1: Initial exploration

**Strategy**: EP1

**Score**: 0.00045663

**Formula**:
```
a * (1 + b*x)^(-2/3) * exp(-c*r^2)
```

**Reasoning**: Theoretical far-wake decay rate (-2/3) with Gaussian profile.

### Generation 3: Simplified structure

**Strategy**: EP1

**Score**: 0.00034768

**Formula**:
```
a * x^(-2/3) * exp(-b*r^2) / (1 + c*sqrt(k))
```

**Reasoning**: Simplifying by removing the offset in x.

### Generation 6: TKE term refinement

**Strategy**: EP1

**Score**: 0.00034237

**Formula**:
```
x^(-0.6) * exp(-a*r^2) / (1 + b*k)
```

**Reasoning**: Simplifying TKE term to linear.

### Generation 8: Near-wake correction added

**Strategy**: EP1

**Score**: 0.00033598

**Formula**:
```
x^(-0.61) * exp(-a*r^2) / (1 + b*k) * (1 - exp(-c*x))
```

**Reasoning**: Enforcing near-wake zero deficit on the simplified model.

### Generation 10: Removal of near-wake term

**Strategy**: EP1

**Score**: 0.00033466

**Formula**:
```
x^(-0.6) * exp(-a*r^2) / (1 + b*k)
```

**Reasoning**: Removing the near-wake term to see if it's essential.

### Generation 11: Re-addition of near-wake term

**Strategy**: EP1

**Score**: 0.00033388

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k) * (1 - exp(-c*x))
```

**Reasoning**: Fine-tuning decay rate (-0.595) in the best model.

### Generation 13: TKE power optimization

**Strategy**: EP1

**Score**: 0.0003302

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k^0.95) * (1 - exp(-x))
```

**Reasoning**: Adjusting TKE power in the best model (closer to linear).

### Generation 17: Decay rate fine-tuning

**Strategy**: EP1

**Score**: 0.00032933

**Formula**:
```
x^(-0.596) * exp(-a*r^2) / (1 + b*k^0.95) * (1 - exp(-x))
```

**Reasoning**: Fine-tuning decay rate (-0.596) in the best model.

### Generation 20: Final convergence

**Strategy**: EP1

**Score**: 0.00033244

**Formula**:
```
x^(-0.596) * exp(-a*r^2) / (1 + b*k^0.9505) * (1 - exp(-x))
```

**Reasoning**: Fine-tuning TKE power (0.9505) in the best model.

## Complete Evolution History

### Generation 1

- **Strategy**: EP1
- **Score**: 0.00045663

**Formula**:
```
a * (1 + b*x)^(-2/3) * exp(-c*r^2)
```

_Theoretical far-wake decay rate (-2/3) with Gaussian profile._

---

### Generation 2

- **Strategy**: EP1
- **Score**: 0.00037538 (↓ 17.79%)

**Formula**:
```
a * (1 + b*x)^(-2/3) * exp(-c*r^2) / (1 + d*sqrt(k))
```

_Inverse sqrt TKE modulation on the best model._

---

### Generation 3

- **Strategy**: EP1
- **Score**: 0.00034768 (↓ 7.38%)

**Formula**:
```
a * x^(-2/3) * exp(-b*r^2) / (1 + c*sqrt(k))
```

_Simplifying by removing the offset in x._

---

### Generation 4

- **Strategy**: EP1
- **Score**: 0.0003494 (↑ 0.5%)

**Formula**:
```
a * x^(-0.6) * exp(-b*r^2) / (1 + c*sqrt(k))
```

_Adjusting decay rate in the simplified model._

---

### Generation 5

- **Strategy**: EP1
- **Score**: 0.00034856 (↓ 0.24%)

**Formula**:
```
x^(-0.6) * exp(-a*r^2) / (1 + b*sqrt(k))
```

_Removing amplitude coefficient 'a'._

---

### Generation 6

- **Strategy**: EP1
- **Score**: 0.00034237 (↓ 1.78%)

**Formula**:
```
x^(-0.6) * exp(-a*r^2) / (1 + b*k)
```

_Simplifying TKE term to linear._

---

### Generation 7

- **Strategy**: EP1
- **Score**: 0.00033916 (↓ 0.94%)

**Formula**:
```
x^(-0.61) * exp(-a*r^2) / (1 + b*k)
```

_Fine-tuning decay rate (-0.61) in the simplified model._

---

### Generation 8

- **Strategy**: EP1
- **Score**: 0.00033598 (↓ 0.94%)

**Formula**:
```
x^(-0.61) * exp(-a*r^2) / (1 + b*k) * (1 - exp(-c*x))
```

_Enforcing near-wake zero deficit on the simplified model._

---

### Generation 9

- **Strategy**: EP1
- **Score**: 0.00033261 (↓ 1.0%)

**Formula**:
```
x^(-0.6) * exp(-a*r^2) / (1 + b*k) * (1 - exp(-c*x))
```

_Re-evaluating decay rate (-0.6) in the best model._

---

### Generation 10

- **Strategy**: EP1
- **Score**: 0.00033466 (↑ 0.62%)

**Formula**:
```
x^(-0.6) * exp(-a*r^2) / (1 + b*k)
```

_Removing the near-wake term to see if it's essential._

---

### Generation 11

- **Strategy**: EP1
- **Score**: 0.00033388 (↓ 0.23%)

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k) * (1 - exp(-c*x))
```

_Fine-tuning decay rate (-0.595) in the best model._

---

### Generation 12

- **Strategy**: EP1
- **Score**: 0.00033642 (↑ 0.76%)

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k) * (1 - exp(-x))
```

_Simplifying by fixing the near-wake decay rate to 1._

---

### Generation 13

- **Strategy**: EP1
- **Score**: 0.0003302 (↓ 1.85%)

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k^0.95) * (1 - exp(-x))
```

_Adjusting TKE power in the best model (closer to linear)._

---

### Generation 14

- **Strategy**: EP1
- **Score**: 0.00033182 (↑ 0.49%)

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k^0.98) * (1 - exp(-x))
```

_Adjusting TKE power in the best model (0.98)._

---

### Generation 15

- **Strategy**: EP1
- **Score**: 0.00033401 (↑ 0.66%)

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k^0.95) * tanh(x)
```

_Using tanh for near-wake correction._

---

### Generation 16

- **Strategy**: EP1
- **Score**: 0.00033047 (↓ 1.06%)

**Formula**:
```
x^(-0.595) * exp(-a*r^2) / (1 + b*k) * (1 - exp(-x))
```

_Simplifying TKE power to linear (1.0)._

---

### Generation 17

- **Strategy**: EP1
- **Score**: 0.00032933 (↓ 0.35%)

**Formula**:
```
x^(-0.596) * exp(-a*r^2) / (1 + b*k^0.95) * (1 - exp(-x))
```

_Fine-tuning decay rate (-0.596) in the best model._

---

### Generation 18

- **Strategy**: EP1
- **Score**: 0.00033172 (↑ 0.73%)

**Formula**:
```
x^(-0.5955) * exp(-a*r^2) / (1 + b*k^0.95) * (1 - exp(-x))
```

_Fine-tuning decay rate (-0.5955) in the best model._

---

### Generation 19

- **Strategy**: EP1
- **Score**: 0.00033063 (↓ 0.33%)

**Formula**:
```
x^(-0.5958) * exp(-a*r^2) / (1 + b*k^0.95) * (1 - exp(-x))
```

_Fine-tuning decay rate (-0.5958) in the best model._

---

### Generation 20

- **Strategy**: EP1
- **Score**: 0.00033244 (↑ 0.55%)

**Formula**:
```
x^(-0.596) * exp(-a*r^2) / (1 + b*k^0.9505) * (1 - exp(-x))
```

_Fine-tuning TKE power (0.9505) in the best model._

---

## Evolution Summary Table

| Gen | Strategy | Score | Key Change |
|-----|----------|-------|------------|
|  1 | EP1 | 0.000457 |  |
|  2 | EP1 | 0.000375 | \sqrt{k} |
|  3 | EP1 | 0.000348 | \sqrt{k} |
|  4 | EP1 | 0.000349 | \sqrt{k} |
|  5 | EP1 | 0.000349 | \sqrt{k} |
|  6 | EP1 | 0.000342 | TKE term |
|  7 | EP1 | 0.000339 | TKE term |
|  8 | EP1 | 0.000336 | TKE term, near-wake |
|  9 | EP1 | 0.000333 | TKE term, near-wake |
| 10 | EP1 | 0.000335 | TKE term |
| 11 | EP1 | 0.000334 | TKE term, near-wake |
| 12 | EP1 | 0.000336 | TKE term, near-wake |
| 13 | EP1 | 0.000330 | k^{0.95}, near-wake |
| 14 | EP1 | 0.000332 | k^{0.98}, near-wake |
| 15 | EP1 | 0.000334 | k^{0.95} |
| 16 | EP1 | 0.000330 | TKE term, near-wake |
| 17 | EP1 | 0.000329 | k^{0.95}, near-wake |
| 18 | EP1 | 0.000332 | k^{0.95}, near-wake |
| 19 | EP1 | 0.000331 | k^{0.95}, near-wake |
| 20 | EP1 | 0.000332 | k^{0.9505}, near-wake |

## Statistical Summary

- **Initial Score (Gen 1)**: 0.00045663
- **Final Score (Gen 20)**: 0.00033244
- **Total Improvement**: 27.2%
- **Best Score**: 0.00032933 (Gen 17)

