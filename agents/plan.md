# Excluvision Module Treemap - Development Plan

## Overview

A golem Shiny module that displays ICD-10 codes as an interactive treemap, allowing users to select codes and visualize their hierarchical distribution.

## Data Structure

-   **Source**: `cim.parquet` (42,496 ICD-10 codes), cim_hiera.rda (ICD-10 hierarchies)
-   **Columns**:
    -   ICD-10: `code`, `lib` (short label), `liblong` (full label), `hiera` (hierarchy e.g., "01.01", "02.01.03")
    -   Hierarchies : `hiera`, `diag_deb` (first code), `diag_fin` (last code), `lib` (label)
-   **Hierarchy levels**: Chapter (first segment) → Category (second) → Subcategory (third, optional)

------------------------------------------------------------------------

## Tech Stack Decision

### ICD-10 Input Selection

| Package | Pros | Cons | Verdict |
|-------------------|------------------|------------------|-------------------|
| **shinyWidgets::virtualSelectInput** | Server-side search, handles large lists (40k+ items), good UX | Slightly complex setup | ✅ **RECOMMENDED** |
| shinyWidgets::pickerInput | Nice UI, searchable | Struggles with 40k+ items | ❌ |
| selectize (base shiny) | Built-in | Performance issues at scale | ❌ |

### Treemap Visualization

| Package | Pros | Cons | Verdict |
|-------------------|------------------|------------------|-------------------|
| **r2d3** + custom D3.js | Full control, modern D3.js, CRAN maintained, perfect for Shiny | Requires writing D3.js script | ✅ **RECOMMENDED** |
| d3treeR (d3.js wrapper) | Built-in drill-down | ❌ **NOT ON CRAN**, last commit 2018, abandoned | ❌ |
| treemap (static) | Simple, reliable | No interactivity, no drill-down | ❌ |
| plotly treemap | Interactive | Less natural drill-down, heavier | ❌ |
| highcharter | Beautiful, drill-down possible | License concerns, complex API | ❌ |
| echarts4r | Good treemap, drill-down | Documentation sparse | Alternative |

**Why r2d3 over d3treeR:**
1. **d3treeR is abandoned** - last commit Feb 2018, not on CRAN
2. **r2d3 is RStudio-maintained** - active development, proper Shiny integration  
3. **Full D3.js control** - we can write exactly the treemap we want with drill-down
4. **Modern D3.js** - can use D3 v7 instead of whatever old version d3treeR bundles
5. **Better testability** - D3 script is a separate file, easier to debug

### Data Loading

| Package | Pros | Cons | Verdict |
|-------------------|------------------|------------------|-------------------|
| **nanoparquet** | Lightweight, fast, no dependencies | Read-only | ✅ **RECOMMENDED** |
| arrow | Full parquet support | Heavy dependency | ❌ overkill |

### Final Stack

```         
shinyWidgets::virtualSelectInput  → ICD-10 selection (handles 40k+ codes)
r2d3 + custom treemap.js          → Hierarchical treemap with drill-down
nanoparquet                       → Data loading
```

------------------------------------------------------------------------

## Phase Overview

| Phase | Description                         | Status  |
|-------|-------------------------------------|---------|
| 1.0   | Data layer & hierarchy parsing      | ✅ DONE |
| 2.0   | Basic treemap display (static)      | ✅ DONE |
| 3.0   | ICD-10 input selector               | ⬜ TODO |
| 4.0   | Wire input → treemap reactivity     | ⬜ TODO |
| 5.0   | Interactive drill-down with r2d3    | ⬜ TODO |

------------------------------------------------------------------------

## Phase 1.0: Data Layer & Hierarchy Parsing

**Goal**: Load ICD-10 data and hierarchies from cim_hiera.rda and parse hierarchy into usable format for treemap.

**Exit criteria**: - \[x\] Function to load parquet data - \[x\] Function to parse `hiera` column into chapter/category/subcategory - \[x\] Unit tests pass

**Implementation notes**: - Parse "01.02.03" → chapter="01", category="02", subcategory="03" - Handle variable depth (some codes have 2 levels, some have 3)

------------------------------------------------------------------------

## Phase 2.0: Basic Treemap Display

**Goal**: Render a static treemap showing selected ICD-10 codes by hierarchy.

**Exit criteria**: - \[ \] Function to aggregate codes by hierarchy level - \[ \] treemap renders correctly given a subset of codes - \[ \] Unit tests for aggregation logic

**Implementation notes**: - Use `treemap::treemap()` for initial static version - Aggregate by chapter first, then allow drill into categories

------------------------------------------------------------------------

## Phase 3.0: ICD-10 Input Selector

**Goal**: Create input widget for selecting ICD-10 codes.

**Exit criteria**: - \[ \] virtualSelectInput displays all 40k+ codes - \[ \] Search works (by code and label) - \[ \] Multiple selection enabled - \[ \] Shiny module wrapper (`mod_icd_selector_ui/server`)

**Implementation notes**: - Use `shinyWidgets::virtualSelectInput` for performance - Format choices as "A00 - CHOLERA" for searchability

------------------------------------------------------------------------

## Phase 4.0: Reactive Integration

**Goal**: Connect input selection to treemap rendering.

**Exit criteria**: - \[ \] Selecting codes updates treemap - \[ \] Empty selection shows message or placeholder - \[ \] Performance acceptable (\<1s for typical selections)

------------------------------------------------------------------------

## Phase 5.0: Interactive Drill-Down

**Goal**: Add interactive drill-down using r2d3 custom D3.js treemap.

**Exit criteria**: - \[ \] Click on chapter drills into categories - \[ \] Breadcrumb or back navigation - \[ \] Smooth transitions

**Implementation notes**: 
- Use `r2d3::r2d3()` with custom `inst/d3/treemap.js` script
- D3 script receives hierarchical JSON data from R
- Implement zoom transitions in D3.js
- Shiny message passing for R → D3 and D3 → R communication

------------------------------------------------------------------------

## Deferred / Out of Scope

-   Export functionality
-   Custom color schemes
-   Tooltips with detailed info
-   Comparison mode (multiple selections)

These can be added after core functionality works.

------------------------------------------------------------------------

## Architecture

```         
R/
├── mod_treemap.R          # Main module (UI + server)
├── mod_icd_selector.R     # ICD selector submodule  
├── fct_data.R             # Data loading & parsing functions
├── fct_treemap.R          # Treemap preparation functions
└── utils_hierarchy.R      # Hierarchy parsing utilities

inst/
└── d3/
    └── treemap.js         # Custom D3.js treemap with drill-down
```