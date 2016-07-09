build_macro_mkPaths()
FIND_FINAL_TARGET()

set(CSS_SRCS
    ${mk_srcdir}/alt1-c.css
    ${mk_srcdir}/alt1-cgi.css
    ${mk_srcdir}/alt1-cpp.css
    ${mk_srcdir}/alt1-idl.css
    ${mk_srcdir}/alt1-mk.css
    ${mk_srcdir}/alt1-pl.css
    ${mk_srcdir}/alt1-pm.css
    ${mk_srcdir}/alt2-cgi.css
    ${mk_srcdir}/alt2-pl.css
    ${mk_srcdir}/alt2-pm.css
    ${mk_srcdir}/cgi.css
    ${mk_srcdir}/h.css
    ${mk_srcdir}/idl.css
    ${mk_srcdir}/pl.css
    ${mk_srcdir}/pm.css
    ${mk_srcdir}/style.css
)

set(SOURCE_FILES
    ${CSS_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")