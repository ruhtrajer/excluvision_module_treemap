# Excluvision Module Treemap - Development Plan

## Overview
A golem Shiny module that displays ICD-10 codes as an interactive treemap, allowing users to select codes and visualize their hierarchical distribution.

## Data Structure
- **Source**: `cim.parquet` (42,496 ICD-10 codes)
- **Columns**: `code`, `lib` (short label), `liblong` (full label), `hiera` (hierarchy e.g., "01.01", "02.01.03")
- **Hierarchy levels**: Chapter (first segment) → Category (second) → Subcategory (third, optional)

---

## Tech Stack Decision

### ICD-10 Input Selection

| Package | Pros | Cons | Verdict |
|---------|------|------|---------|
| **shinyWidgets::virtualSelectInput** | Server-side search, handles large lists (40k+ items), good UX | Slightly complex setup | ✅ **RECOMMENDED** |
| shinyWidgets::pickerInput | Nice UI, searchable | Struggles with 40k+ items | ❌ |
| selectize (base shiny) | Built-in | Performance issues at scale | ❌ |

### Treemap Visualization

| Package | Pros | Cons | Verdict |
|---------|------|------|---------|
| **d3treeR** (d3.js wrapper) | Interactive drill-down built-in, good for hierarchical exploration | Depends on {treemap} for data prep | ✅ **RECOMMENDED** |
| treemap (static) | Simple, reliable | No interactivity, no drill-down | ❌ |
| plotly treemap | Interactive | Less natural drill-down, heavier | ❌ |
| highcharter | Beautiful, drill-down possible | License concerns, complex API | ❌ |
| echarts4r | Good treemap, drill-down | Documentation sparse | Alternative |

### Data Loading

| Package | Pros | Cons | Verdict |
|---------|------|------|---------|
| **nanoparquet** | Lightweight, fast, no dependencies | Read-only | ✅ **RECOMMENDED** |
| arrow | Full parquet support | Heavy dependency | ❌ overkill |

### Final Stack
```
shinyWidgets::virtualSelectInput  → ICD-10 selection (handles 40k+ codes)
treemap + d3treeR                 → Hierarchical treemap with drill-down
nanoparquet                       → Data loading
```

---

## Phase Overview

| Phase | Description | Status |
|-------|-------------|--------|
| 1.0 | Data layer & hierarchy parsing | ⬜ TODO |
| 2.0 | Basic treemap display (static) | ⬜ TODO |
| 3.0 | ICD-10 input selector | ⬜ TODO |
| 4.0 | Wire input → treemap reactivity | ⬜ TODO |
| 5.0 | Interactive drill-down with d3treeR | ⬜ TODO |

---

## Phase 1.0: Data Layer & Hierarchy Parsing

**Goal**: Load ICD-10 data and parse hierarchy into usable format for treemap.

**Exit criteria**:
- [x] Function to load parquet data
- [x] Function to parse `hiera` column into chapter/category/subcategory
- [x] Unit tests pass

**Implementation notes**:
- Parse "01.02.03" → chapter="01", category="02", subcategory="03"
- Handle variable depth (some codes have 2 levels, some have 3)

---

## Phase 2.0: Basic Treemap Display

**Goal**: Render a static treemap showing selected ICD-10 codes by hierarchy.

**Exit criteria**:
- [ ] Function to aggregate codes by hierarchy level
- [ ] treemap renders correctly given a subset of codes
- [ ] Unit tests for aggregation logic

**Implementation notes**:
- Use `treemap::treemap()` for initial static version
- Aggregate by chapter first, then allow drill into categories

---

## Phase 3.0: ICD-10 Input Selector

**Goal**: Create input widget for selecting ICD-10 codes.

**Exit criteria**:
- [ ] virtualSelectInput displays all 40k+ codes
- [ ] Search works (by code and label)
- [ ] Multiple selection enabled
- [ ] Shiny module wrapper (`mod_icd_selector_ui/server`)

**Implementation notes**:
- Use `shinyWidgets::virtualSelectInput` for performance
- Format choices as "A00 - CHOLERA" for searchability

---

## Phase 4.0: Reactive Integration

**Goal**: Connect input selection to treemap rendering.

**Exit criteria**:
- [ ] Selecting codes updates treemap
- [ ] Empty selection shows message or placeholder
- [ ] Performance acceptable (<1s for typical selections)

---

## Phase 5.0: Interactive Drill-Down

**Goal**: Replace static treemap with interactive d3treeR for drill-down.

**Exit criteria**:
- [ ] Click on chapter drills into categories
- [ ] Breadcrumb or back navigation
- [ ] Smooth transitions

**Implementation notes**:
- Use `d3treeR::d3tree2()` or `d3tree3()` for interactivity
- May need to restructure data for d3treeR input format

---

## Deferred / Out of Scope

- Export functionality
- Custom color schemes
- Tooltips with detailed info
- Comparison mode (multiple selections)

These can be added after core functionality works.

---

## Architecture

```
R/
├── mod_treemap.R          # Main module (UI + server)
├── mod_icd_selector.R     # ICD selector submodule  
├── fct_data.R             # Data loading & parsing functions
├── fct_treemap.R          # Treemap preparation functions
└── utils_hierarchy.R      # Hierarchy parsing utilities
```
