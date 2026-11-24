library(pdftools)
for (y in 1933:1946) {
  tx <- pdf_text(sprintf("D:/data/spain_mortality/ine_historia_%d.pdf", y))
  for (p in seq_along(tx)) {
    m <- regmatches(tx[p], gregexpr("(?i)(de )?[0-9]{1,3} a(ñ|n|fi|ii)os", tx[p], perl = TRUE))[[1]]
    if (length(m) >= 3 && grepl("(?i)alava|álava", tx[p])) cat(y, p, "|", paste(head(unique(m), 14), collapse = ", "), "\n")
  }
}
