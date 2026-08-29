# aggregator

  {
    newspaper: (.page_id | split("-")[0]),
    year: (.page_id | split("-")[1]),
    page_id: .page_id,
    total_lines: .total_lines,
    num_empty_lines: .pages_stats.num_empty_lines,
    avg_lines_per_paragraph: .pages_stats.avg_lines_per_paragraph,
    avg_paragraphs_per_region: .pages_stats.avg_paragraphs_per_region,
  }
