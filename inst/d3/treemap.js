// @param data - hierarchical data from R
// @param div - D3 selection of container div
// @param width - container width
// @param height - container height
// @param options - additional options from R

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

// Color scale for treemap cells
const color = d3.scaleOrdinal(d3.schemeTableau10);

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

// Track current node for navigation
let currentNode = root;

// Create SVG
const svg = div.append("svg")
  .attr("viewBox", [0, 0, width, height])
  .attr("width", width)
  .attr("height", height)
  .style("font", "10px sans-serif");

// Container for treemap cells
const container = svg.append("g");

// Render function
function render(node) {
  currentNode = node;
  
  // Clear and rebuild
  container.selectAll("*").remove();
  
  // Get direct children to display
  const displayNodes = node.children || [];
  if (displayNodes.length === 0) return;
  
  // Recompute layout for current view
  const tempRoot = d3.hierarchy(node.data)
    .sum(d => d.value)
    .sort((a, b) => b.value - a.value);
  
  treemap(tempRoot);
  
  // Only show direct children (depth 1 from current node)
  const cells = tempRoot.children || [];
  
  cells.forEach(d => {
    const cell = container.append("g")
      .attr("transform", `translate(${d.x0},${d.y0})`);
    
    // Find original node for drill-down reference
    const origNode = node.children ? 
      node.children.find(c => (c.data.id || c.data.name) === (d.data.id || d.data.name)) : 
      null;
    
    const hasChildren = origNode && origNode.children && origNode.children.length > 0;
    
    // Rectangle
    cell.append("rect")
      .attr("width", Math.max(0, d.x1 - d.x0))
      .attr("height", Math.max(0, d.y1 - d.y0))
      .attr("fill", color(d.data.id || d.data.name))
      .attr("stroke", "#fff")
      .attr("stroke-width", 1)
      .style("cursor", hasChildren ? "pointer" : "default")
      .on("click", (event) => {
        // Single click: drill down if has children
        if (hasChildren) {
          render(origNode);
        }
      })
      .on("dblclick", (event) => {
        // Double click: go back up one level
        event.stopPropagation();
        if (currentNode.parent) {
          render(currentNode.parent);
        }
      });
    
    // Clip path for text
    const clipId = "clip-" + (d.data.id || d.data.name).replace(/[.\s]/g, "-");
    cell.append("clipPath")
      .attr("id", clipId)
      .append("rect")
      .attr("width", Math.max(0, d.x1 - d.x0))
      .attr("height", Math.max(0, d.y1 - d.y0));
    
    // Label
    const w = d.x1 - d.x0;
    const h = d.y1 - d.y0;
    let labelText = d.data.name || d.data.id || "";
    
    if (w < 30 || h < 15) {
      labelText = "";
    } else if (w < 60) {
      labelText = labelText.substring(0, 5) + (labelText.length > 5 ? "..." : "");
    } else if (w < 100) {
      labelText = labelText.substring(0, 15) + (labelText.length > 15 ? "..." : "");
    }
    
    cell.append("text")
      .attr("clip-path", `url(#${clipId})`)
      .attr("x", 4)
      .attr("y", 13)
      .style("fill", "white")
      .style("font-weight", "bold")
      .style("font-size", w > 100 ? "12px" : w > 50 ? "10px" : "8px")
      .style("pointer-events", "none")
      .text(labelText);
    
    // Tooltip
    cell.append("title")
      .text(`${d.data.name}\n${d.value} codes${hasChildren ? "\n(click to drill down)" : ""}`);
  });
  
  // Send message to Shiny
  if (typeof Shiny !== "undefined" && options && options.inputId) {
    Shiny.setInputValue(options.inputId + "_drill", {
      id: node.data.id,
      name: node.data.name,
      depth: node.depth
    });
  }
}

// Initial render at root level
render(root);
