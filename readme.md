# Wind Turbine Fatigue Analysis

MATLAB implementation for fatigue assessment of wind turbine structural components (main shaft and tower) based on the 2023 Post-Graduate Mathematical Contest in Modeling (Problem A).

## 📋 Overview

This project provides a comprehensive framework for evaluating fatigue loads and cumulative damage of wind turbine components under operational conditions. The code implements the Palmgren-Miner linear damage rule combined with the Goodman mean stress correction method, utilizing rainflow cycle counting for load spectrum analysis.

## 🎯 Problem Description

The fatigue assessment of wind turbines is critical for ensuring structural integrity and operational safety. This solution addresses:
- **Main Shaft Torque Analysis**: Evaluating torsional fatigue loads
- **Tower Thrust Analysis**: Assessing bending fatigue from aerodynamic forces
- **100 Turbine Batch Processing**: Comparative analysis across multiple units

## 🔧 Methodology

### 1. Data Processing
- Extract peaks and valleys from time-series load data
- Eliminate redundant turning points for efficient counting

### 2. Cycle Counting
- Three-point rainflow counting algorithm
- Identifies full and half cycles from load history

### 3. Mean Stress Correction
- Goodman correction formula: `S_i = amplitude / (1 - mean/σ_b)`
- Accounts for mean stress effects on fatigue life

### 4. Fatigue Assessment
- **Equivalent Fatigue Load**: `L_eq = (Σ(S_i^m × n_i) / N)^(1/m)`
- **Cumulative Damage**: `D = Σ(n_i / (C / S_i^m))`
- Palmgren-Miner linear damage accumulation rule

## 📁 Repository Structure

```
Post-Graduate_MCM/
├── README.md
├── fatigue_analysis.m          # Main script
├── data/
│   └── 附件1-疲劳评估数据.xls   # Input data file
└── results/
    └── output_plots.fig        # Generated visualization
```