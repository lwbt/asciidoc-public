#!/bin/bash

# cspell:ignore pdfwrite PDFSETTINGS NOPAUSE docbook pandoc Ghostscript howtogeek

THEME_EN="assets/themes/my-theme-en.yml"
FILE_NAME="document"
# Set to "Y" to create docx. Results do not meet my expectations.
CREATE_DOCX="N"

# Optimize the results with asciidoctor-pdf-optimize or Ghostscript.
# Choose one of these! Not both!
# Currently none of the options provide a significant size benefit.
#
# Use asciidoctor-pdf-optimize to optimize the results. Appears to be broken right now.
OPTIMIZE_PDF_1="N"
# Use Ghostscript to optimize the results. Size reduction is negligible.
OPTIMIZE_PDF_GS="N"

create_document() {
  local source_adoc="${1}"
  local source_pdf="${2}"
  local source_pdf_opt="${3}"
  local theme="${4}"

  # Call asciidoctor and measure its execution time, finally provide a nice
  # output.
  #
  # Example:
  # 0:01.11s file: <some_file.adoc.pdf>
  #
  if [[ "${OPTIMIZE_PDF_1:-}" == "Y" || "${OPTIMIZE_PDF_GS:-}" == "Y" ]]; then

    /usr/bin/time -f "$(date +"%F %T") %E %C" \
      asciidoctor-pdf \
      --attribute compress \
      --theme "${theme}" \
      "${source_adoc}" \
      --out-file "${source_pdf}" 2>&1 \
      | sed 's/asciidoctor-pdf .* --out-file/File created:/'

    [[ "${OPTIMIZE_PDF_1:-}" == "Y" ]] && optimize_document_1

    [[ "${OPTIMIZE_PDF_GS:-}" == "Y" ]] && optimize_document_gs

  else

    /usr/bin/time -f "$(date +"%F %T") %E %C" \
      asciidoctor-pdf \
      --attribute compress \
      --theme "${theme}" \
      "${source_adoc}" \
      --out-file "${source_pdf_opt}" 2>&1 \
      | sed 's/asciidoctor-pdf .* --out-file/File created:/'

  fi

  #optimize_document

  #mv -v "${source_pdf}" "${source_pdf_opt}"

  [[ "${CREATE_DOCX:-}" == "Y" ]] && convert_to_docx
}

optimize_document_1() {
  # TODO: This function turned out to have bring no size advantage.

  # Not required? File Size seems small enough.
  asciidoctor-pdf-optimize --theme "${theme}" "${source_adoc}"

  rm "${source_pdf}"
}

optimize_document_gs() {

  # Optional, included particularly since asciidoctor-pdf-optimize does not work
  # right now and because the unoptimized result is twice the size of a similar
  # document made in LibreOffice Writer?
  # https://askubuntu.com/questions/113544/how-can-i-reduce-the-file-size-of-a-scanned-pdf-file
  /usr/bin/time -f "$(date +"%F %T") %E %C" \
    gs \
    -sDEVICE=pdfwrite \
    -dCompatibilityLevel=1.4 \
    -dPDFSETTINGS=/ebook \
    -dNOPAUSE \
    -dQUIET \
    -dBATCH \
    -sOutputFile="${source_pdf_opt}" \
    "${source_pdf}" 2>&1 | sed "{s/gs .* -sOutputFile=/Optimized file created: /;s/ ${source_pdf}//}"

  rm "${source_pdf}"
}

convert_to_docx() {
  # ALTERNATIVE: https://www.howtogeek.com/269776/how-to-convert-pdf-files-and-images-into-google-docs-documents/
  # https://rmoff.net/2020/04/16/converting-from-asciidoc-to-google-docs-and-ms-word/
  # https://docs-as-co.de/news/create-docx/
  # TODO: https://github.com/dagwieers/asciidoc-odf
  # https://stackoverflow.com/questions/70513062/how-do-i-add-custom-formatting-to-docx-files-generated-in-pandoc
  # https://pypi.org/project/pandoc-docx-pagebreak/
  /usr/bin/time -f "$(date +"%F %T") %E %C" \
    asciidoctor \
    --backend docbook \
    --out-file - \
    "${source_adoc}" \
    | /usr/bin/time -f "$(date +"%F %T") %E %C" \
      pandoc \
      --from docbook \
      --to docx \
      --reference-doc="assets/custom-reference.docx" \
      --output "${source_adoc}.docx"
}

main() {

  if [[ "${OPTIMIZE_PDF_1:-}" == "Y" && "${OPTIMIZE_PDF_GS:-}" == "Y" ]]; then
    echo "Not allowed!"
    exit 1
  fi

  start_time=$(date +%s.%2N)

  # Since we run a few functions here in parallel while we don't care about
  # order, we pretend we can measure execution time. Thus we start with this
  # output.
  echo "$(date +"%F %T") 0:00.00 Creating files..."

  # PERSONAL EN VERSION

  SOURCE_ADOC="${FILE_NAME}.en.adoc"
  SOURCE_PDF="${FILE_NAME}.en.pdf"
  SOURCE_PDF_OPT="${FILE_NAME}.adoc.pdf"
  create_document "${SOURCE_ADOC}" "${SOURCE_PDF}" "${SOURCE_PDF_OPT}" "${THEME_EN}" &

  wait

  end_time=$(date +%s.%2N)

  #elapsed=$(( end_time - start_time ))
  #echo "${elapsed}s"

  elapsed=$(bc <<< "scale=3; ${end_time} - ${start_time}")
  # Execution is supposed to take less than a minute, this hack is acceptable for now.
  LC_NUMERIC="en_US.UTF-8" printf "$(date +"%F %T") 0:%05.2f TOTAL TIME ELAPSED IN SECONDS\n" "${elapsed}"
}

main "$@"
