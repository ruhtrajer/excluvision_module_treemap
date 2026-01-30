# Phase 5.0: Interactive Drill-Down Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace static treemap with an interactive D3.js treemap that supports drill-down navigation through ICD-10 hierarchy levels.

**Architecture:** Use `r2d3` package to render a custom D3.js treemap. The R side prepares hierarchical JSON data, D3.js handles rendering and click interactions. Clicking a rectangle drills into that group's children. A breadcrumb trail allows navigation back up the hierarchy. Shiny message passing handles D3→R communication for drill state.

**Tech Stack:** r2d3 for R↔D3.js integration, D3.js v7 for treemap visualization, jsonlite for JSON conversion.

---

## Pre-requisites

- Phase 3.0/4.0 complete: selector and treemap modules working
- Add `r2d3` and `jsonlite` packages to DESCRIPTION Imports

---

## Task 1: Add r2d3 and jsonlite dependencies

**Files:**
- Modify: `DESCRIPTION`

**Step 1: Add packages to Imports**

Edit `DESCRIPTION` Imports section:

```
Imports: 
    config,
    golem,
    jsonlite,
    nanoparquet,
    r2d3,
    shiny,
    shinyWidgets,
    treemap
```

**Step 2: Verify installation**

Run: `Rscript -e "for(p in c('r2d3', 'jsonlite')) { if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos='https://cloud.r-project.org', quiet=TRUE) }; library(r2d3); library(jsonlite); cat('r2d3:', as.character(packageVersion('r2d3')), 'jsonlite:', as.character(packageVersion('jsonlite')))"`

Expected: Version numbers printed

**Step 3: Commit**

```bash
git add DESCRIPTION
git commit -m "chore: add r2d3 and jsonlite dependencies for interactive treemap"
```

---

## Task 2: Create hierarchical data builder with TDD

**Files:**
- Modify: `tests/testthat/test-fct_treemap.R`
- Modify: `R/fct_treemap.R`

### Step 1: Write failing tests for build_treemap_hierarchy()

Append to `tests/testthat/test-fct_treemap.R`:

```r
test_that("build_treemap_hierarchy returns list with name and children", {
  test_data <- data.frame(
    code = c("A00", "A01", "B00"),
    lib = c("Disease A", "Disease B", "Disease C"),
    chapter = c("01", "01", "02"),
    category = c("01", "01", "01"),
    subcategory = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )

  result <- build_treemap_hierarchy(test_data)

  expect_type(result, "list")
  expect_true("name" %in% names(result))
  expect_true("children" %in% names(result))
})

test_that("build_treemap_hierarchy creates correct chapter-level structure", {
  test_data <- data.frame(
    code = c("A00", "A01", "B00", "B01", "B02"),
    lib = c("D1", "D2", "D3", "D4", "D5"),
    chapter = c("01", "01", "02", "02", "02"),
    category = c("01", "01", "01", "02", "02"),
    subcategory = c(NA, NA, NA, NA, NA),
    stringsAsFactors = FALSE
  )

  result <- build_treemap_hierarchy(test_data)

  # Root should have children for each chapter
expect_equal(length(result$children), 2)
  # Find chapter 01 and 02
  ch01 <- Filter(function(x) x$id == "01", result$children)[[1]]
  ch02 <- Filter(function(x) x$id == "02", result$children)[[1]]
  expect_equal(ch01$value, 2)
  expect_equal(ch02$value, 3)
})

test_that("build_treemap_hierarchy includes category children", {
  test_data <- data.frame(
    code = c("A00", "A01", "A10"),
    lib = c("D1", "D2", "D3"),
    chapter = c("01", "01", "01"),
    category = c("01", "01", "02"),
    subcategory = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )

  result <- build_treemap_hierarchy(test_data)

  # Chapter 01 should have category children
  ch01 <- result$children[[1]]
  expect_true("children" %in% names(ch01))
  expect_equal(length(ch01$children), 2)
})

test_that("build_treemap_hierarchy handles empty data", {
  test_data <- data.frame(
    code = character(0),
    lib = character(0),
    chapter = character(0),
    category = character(0),
    subcategory = character(0),
    stringsAsFactors = FALSE
  )

  result <- build_treemap_hierarchy(test_data)

  expect_equal(result$name, "root")
  expect_equal(length(result$children), 0)
})

test_that("build_treemap_hierarchy adds labels from hierarchy lookup", {
  icd_data <- get_icd_data()
  enriched <- enrich_icd_data(icd_data)
  subset_data <- enriched[enriched$chapter == "01", ][1:50, ]

  result <- build_treemap_hierarchy(subset_data)

  # Chapter should have a meaningful label, not just "01"
  ch01 <- result$children[[1]]
  expect_true(nchar(ch01$name) > 2)
})
```

### Step 2: Run tests to verify they fail

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: 5 new tests FAIL with "could not find function 'build_treemap_hierarchy'"

### Step 3: Implement build_treemap_hierarchy()

Append to `R/fct_treemap.R`:

```r
#' Build hierarchical data structure for D3.js treemap
#'
#' Converts flat ICD data into a nested hierarchy suitable for D3.js
#' treemap visualization. Structure: root -> chapters -> categories -> subcategories.
#'
#' @param data Enriched ICD data frame (from enrich_icd_data)
#' @return Nested list with name, children, and value fields for D3.js
#' @export
build_treemap_hierarchy <- function(data) {
  if (nrow(data) == 0) {
    return(list(name = "root", children = list()))
  }

  # Load hierarchy lookup for labels
  hiera_lookup <- get_hierarchy_lookup()

  # Helper to get label from lookup
  get_label <- function(hiera_code) {
    idx <- match(hiera_code, hiera_lookup$hiera)
    if (is.na(idx)) return(hiera_code)
    hiera_lookup$lib[idx]
  }

  # Build nested structure
  chapters <- unique(data$chapter)
  chapters <- chapters[!is.na(chapters)]

  children <- lapply(chapters, function(ch) {
    ch_data <- data[data$chapter == ch, , drop = FALSE]
    ch_label <- get_label(ch)

    # Get categories within this chapter
    categories <- unique(ch_data$category)
    categories <- categories[!is.na(categories)]

    if (length(categories) == 0) {
      # Leaf node - just codes
      return(list(
        name = ch_label,
        id = ch,
        value = nrow(ch_data)
      ))
    }

    cat_children <- lapply(categories, function(cat) {
      cat_data <- ch_data[ch_data$category == cat, , drop = FALSE]
      cat_hiera <- paste(ch, cat, sep = ".")
      cat_label <- get_label(cat_hiera)

      # Get subcategories within this category
      subcats <- unique(cat_data$subcategory)
      subcats <- subcats[!is.na(subcats)]

      if (length(subcats) == 0) {
        # Leaf node
        return(list(
          name = cat_label,
          id = cat_hiera,
          value = nrow(cat_data)
        ))
      }

      subcat_children <- lapply(subcats, function(subcat) {
        subcat_data <- cat_data[cat_data$subcategory == subcat, , drop = FALSE]
        subcat_hiera <- paste(ch, cat, subcat, sep = ".")
        subcat_label <- get_label(subcat_hiera)

        list(
          name = subcat_label,
          id = subcat_hiera,
          value = nrow(subcat_data)
        )
      })

      list(
        name = cat_label,
        id = cat_hiera,
        value = nrow(cat_data),
        children = subcat_children
      )
    })

    list(
      name = ch_label,
      id = ch,
      value = nrow(ch_data),
      children = cat_children
    )
  })

  list(name = "root", children = children)
}
```

### Step 4: Run tests to verify they pass

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: All tests PASS

### Step 5: Commit

```bash
git add R/fct_treemap.R tests/testthat/test-fct_treemap.R
git commit -m "feat: add build_treemap_hierarchy for D3.js data structure"
```

---

## Task 3: Create D3.js treemap script

**Files:**
- Create: `inst/d3/treemap.js`

### Step 1: Create inst/d3 directory

Run: `mkdir -p inst/d3`

### Step 2: Create treemap.js with drill-down functionality

Create `inst/d3/treemap.js`:

```javascript
// @param data - hierarchical data from R
// @param div - D3 selection of container div
// @param width - container width
// @param height - container height
// @param options - additional options from R

// Color scale for treemap cells
const color = d3.scaleOrdinal(d3.schemeTableau10);

// Current view state
let currentRoot = null;
let currentDepth = 0;

// Create treemap layout
const treemap = d3.treemap()
  .size([width, height])
  .paddingOuter(3)
  .paddingTop(19)
  .paddingInner(1)
  .round(true);

// Process hierarchical data
const hierarchy = d3.hierarchy(data)
  .sum(d => d.value)
  .sort((a, b) => b.value - a.value);

const root = treemap(hierarchy);
currentRoot = root;

// Create SVG
const svg = div.append("svg")
  .attr("viewBox", [0, 0, width, height])
  .attr("width", width)
  .attr("height", height)
  .style("font", "10px sans-serif");

// Breadcrumb container
const breadcrumb = div.insert("div", ":first-child")
  .attr("class", "breadcrumb")
  .style("padding", "5px 10px")
  .style("background", "#f5f5f5")
  .style("border-bottom", "1px solid #ddd")
  .style("font-size", "12px");

updateBreadcrumb([{name: "All", node: root}]);

// Container for treemap cells
const container = svg.append("g");

// Render function
function render(node) {
  currentRoot = node;
  
  // Get children or self if leaf
  const nodes = node.children ? node.descendants().slice(1) : [node];
  
  // Update layout for current view
  if (node !== root) {
    // Recompute layout for zoomed view
    const tempHierarchy = d3.hierarchy(node.data)
      .sum(d => d.value)
      .sort((a, b) => b.value - a.value);
    treemap(tempHierarchy);
    
    // Map positions
    const posMap = new Map();
    tempHierarchy.descendants().forEach(d => {
      posMap.set(d.data.id || d.data.name, {x0: d.x0, y0: d.y0, x1: d.x1, y1: d.y1});
    });
    
    nodes.forEach(d => {
      const pos = posMap.get(d.data.id || d.data.name);
      if (pos) {
        d.x0 = pos.x0;
        d.y0 = pos.y0;
        d.x1 = pos.x1;
        d.y1 = pos.y1;
      }
    });
  }

  // Data join
  const cell = container.selectAll("g.cell")
    .data(node.children || [], d => d.data.id || d.data.name);

  // Exit
  cell.exit()
    .transition()
    .duration(300)
    .style("opacity", 0)
    .remove();

  // Enter
  const cellEnter = cell.enter()
    .append("g")
    .attr("class", "cell")
    .style("opacity", 0);

  cellEnter.append("rect");
  cellEnter.append("clipPath")
    .attr("id", d => "clip-" + (d.data.id || d.data.name).replace(/\./g, "-"))
    .append("rect");
  cellEnter.append("text")
    .attr("clip-path", d => "url(#clip-" + (d.data.id || d.data.name).replace(/\./g, "-") + ")");
  cellEnter.append("title");

  // Merge enter + update
  const cellMerge = cellEnter.merge(cell);

  cellMerge.transition()
    .duration(300)
    .style("opacity", 1)
    .attr("transform", d => `translate(${d.x0},${d.y0})`);

  cellMerge.select("rect")
    .attr("fill", d => {
      // Color by top-level ancestor
      let p = d;
      while (p.depth > 1) p = p.parent;
      return color(p.data.id || p.data.name);
    })
    .attr("stroke", "#fff")
    .attr("stroke-width", 1)
    .transition()
    .duration(300)
    .attr("width", d => Math.max(0, d.x1 - d.x0))
    .attr("height", d => Math.max(0, d.y1 - d.y0));

  cellMerge.select("clipPath rect")
    .attr("width", d => Math.max(0, d.x1 - d.x0))
    .attr("height", d => Math.max(0, d.y1 - d.y0));

  cellMerge.select("text")
    .attr("x", 4)
    .attr("y", 13)
    .style("fill", "white")
    .style("font-weight", "bold")
    .style("font-size", d => {
      const w = d.x1 - d.x0;
      return w > 100 ? "12px" : w > 50 ? "10px" : "8px";
    })
    .text(d => {
      const w = d.x1 - d.x0;
      const name = d.data.name || d.data.id;
      if (w < 30) return "";
      if (w < 60) return name.substring(0, 5) + "...";
      if (w < 100) return name.substring(0, 15) + (name.length > 15 ? "..." : "");
      return name;
    });

  cellMerge.select("title")
    .text(d => `${d.data.name}\n${d.value} codes`);

  // Click handler for drill-down
  cellMerge.select("rect")
    .style("cursor", d => d.children ? "pointer" : "default")
    .on("click", (event, d) => {
      if (d.children) {
        zoomTo(d);
      }
    });
}

// Zoom to a node
function zoomTo(node) {
  // Build breadcrumb path
  const path = [];
  let current = node;
  while (current) {
    path.unshift({name: current.data.name || "All", node: current});
    current = current.parent;
  }
  updateBreadcrumb(path);
  render(node);
  
  // Send message to Shiny
  if (typeof Shiny !== "undefined") {
    Shiny.setInputValue(options.inputId + "_drill", {
      id: node.data.id,
      name: node.data.name,
      depth: node.depth
    });
  }
}

// Update breadcrumb
function updateBreadcrumb(path) {
  breadcrumb.html("");
  
  path.forEach((item, i) => {
    if (i > 0) {
      breadcrumb.append("span").text(" > ");
    }
    
    const link = breadcrumb.append("span")
      .text(item.name)
      .style("cursor", i < path.length - 1 ? "pointer" : "default")
      .style("color", i < path.length - 1 ? "#0066cc" : "#333")
      .style("text-decoration", i < path.length - 1 ? "underline" : "none");
    
    if (i < path.length - 1) {
      link.on("click", () => zoomTo(item.node));
    }
  });
}

// Initial render
render(root);
```

### Step 3: Commit

```bash
git add inst/d3/treemap.js
git commit -m "feat: add D3.js treemap script with drill-down navigation"
```

---

## Task 4: Update mod_treemap to use r2d3

**Files:**
- Modify: `R/mod_treemap.R`

### Step 1: Update mod_treemap_ui to use r2d3 output

Replace `R/mod_treemap.R` content:

```r
#' Treemap Module UI
#'
#' @param id Module namespace id
#' @return Shiny UI tag list
#' @export
mod_treemap_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    r2d3::d3Output(ns("treemap_d3"), height = "500px")
  )
}

#' Treemap Module Server
#'
#' @param id Module namespace id
#' @param selected_codes Reactive expression returning vector of selected ICD codes
#' @return NULL (side effects only)
#' @export
mod_treemap_server <- function(id, selected_codes) {
  shiny::moduleServer(id, function(input, output, session) {
    # Load and enrich data once
    icd_data <- enrich_icd_data(get_icd_data())

    # Filter data based on selected codes
    filtered_data <- shiny::reactive({
      codes <- selected_codes()
      if (is.null(codes) || length(codes) == 0) {
        return(icd_data[0, ])
      }
      icd_data[icd_data$code %in% codes, ]
    })

    # Build hierarchy for D3
    hierarchy_data <- shiny::reactive({
      data <- filtered_data()
      if (nrow(data) == 0) {
        return(NULL)
      }
      build_treemap_hierarchy(data)
    })

    # Render D3 treemap
    output$treemap_d3 <- r2d3::renderD3({
      data <- hierarchy_data()
      if (is.null(data)) {
        # Return empty visualization with message
        return(r2d3::r2d3(
          data = list(name = "root", children = list()),
          script = app_sys("d3/treemap.js"),
          options = list(inputId = session$ns("treemap"))
        ))
      }
      r2d3::r2d3(
        data = data,
        script = app_sys("d3/treemap.js"),
        options = list(inputId = session$ns("treemap"))
      )
    })

    # Observe drill-down events from D3
    shiny::observeEvent(input$treemap_drill, {
      drill_info <- input$treemap_drill
      # Can be used for additional R-side logic if needed
      # message("Drilled to: ", drill_info$name, " at depth ", drill_info$depth)
    })
  })
}
```

### Step 2: Update module tests

Modify `tests/testthat/test-mod_treemap.R`:

```r
test_that("mod_treemap_ui returns shiny tag list", {
  ui <- mod_treemap_ui("test")
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_treemap_ui contains d3 output", {
  ui <- mod_treemap_ui("test")
  ui_html <- as.character(ui)
  expect_true(grepl("test-treemap_d3", ui_html))
})
```

### Step 3: Run tests

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'mod_treemap')"`

Expected: All 2 tests PASS

### Step 4: Commit

```bash
git add R/mod_treemap.R tests/testthat/test-mod_treemap.R
git commit -m "feat: update mod_treemap to use r2d3 with drill-down"
```

---

## Task 5: Handle empty state in D3

**Files:**
- Modify: `inst/d3/treemap.js`

### Step 1: Add empty state handling to treemap.js

Add this at the beginning of `inst/d3/treemap.js` (after the color scale definition):

```javascript
// Handle empty data
if (!data.children || data.children.length === 0) {
  div.append("div")
    .style("display", "flex")
    .style("align-items", "center")
    .style("justify-content", "center")
    .style("height", height + "px")
    .style("color", "#888")
    .style("font-size", "16px")
    .text("Select ICD-10 codes to display treemap");
  return;
}
```

### Step 2: Commit

```bash
git add inst/d3/treemap.js
git commit -m "feat: add empty state message to D3 treemap"
```

---

## Task 6: Run all tests and generate documentation

**Step 1: Run full test suite**

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test()"`

Expected: All tests PASS (~53 tests)

**Step 2: Generate documentation**

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::document()"`

**Step 3: Commit documentation**

```bash
git add NAMESPACE man/
git commit -m "docs: update documentation for Phase 5.0"
```

---

## Task 7: Human visual verification

**⚠️ STOP: Human review required**

**Instructions for human tester:**

1. Start the Shiny app:
   ```r
   devtools::load_all()
   run_app()
   ```

2. Verify treemap functionality:
   - [ ] Select several ICD codes (mix of different chapters)
   - [ ] Treemap displays with colored rectangles
   - [ ] Breadcrumb shows "All" at top
   - [ ] Click on a chapter rectangle → drills into categories
   - [ ] Breadcrumb updates (e.g., "All > Infectious diseases")
   - [ ] Click breadcrumb link → navigates back up
   - [ ] Hover shows tooltip with name and count

3. Edge cases:
   - [ ] Empty selection shows placeholder message
   - [ ] Single code selection works
   - [ ] Deep drill-down works (chapter → category → subcategory if available)

4. Report any issues before completing.

---

## Exit Criteria Checklist

- [ ] r2d3 and jsonlite packages added to DESCRIPTION
- [ ] `build_treemap_hierarchy()` function works with unit tests
- [ ] D3.js treemap script renders correctly
- [ ] Click on chapter drills into categories
- [ ] Breadcrumb navigation works
- [ ] Smooth transitions on drill-down
- [ ] Empty state handled gracefully
- [ ] All tests pass
- [ ] Human visual verification complete

---

## Files Created/Modified Summary

| File | Action | Purpose |
|------|--------|---------|
| `DESCRIPTION` | Modified | Add r2d3, jsonlite dependencies |
| `R/fct_treemap.R` | Modified | Add build_treemap_hierarchy() |
| `R/mod_treemap.R` | Modified | Switch to r2d3 output |
| `inst/d3/treemap.js` | Created | D3.js treemap with drill-down |
| `tests/testthat/test-fct_treemap.R` | Modified | Add hierarchy tests |
| `tests/testthat/test-mod_treemap.R` | Modified | Update for d3 output |
| `NAMESPACE` | Modified | Exports (via devtools::document) |
| `man/*.Rd` | Modified | Documentation files |
