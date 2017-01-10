build_macro_mkPaths()
FIND_FINAL_TARGET()

set(HTML_SRCS
    ${mk_srcdir}/template-dir
    ${mk_srcdir}/template-head
    ${mk_srcdir}/template-ident-fileref
    ${mk_srcdir}/template-rev
    ${mk_srcdir}/template-rev-entry
    ${mk_srcdir}/template-sourcedir-head
    ${mk_srcdir}/template-sourcedir-tail
    ${mk_srcdir}/template-source-head
    ${mk_srcdir}/template-source-tail
    ${mk_srcdir}/template-tail
    ${mk_srcdir}/template-tree
    ${mk_srcdir}/template-tree-entry
)

set(SOURCE_FILES
    ${HTML_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")