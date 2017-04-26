build_macro_mkPaths()
FIND_FINAL_TARGET()

set(CSS_SRCS
    ${mk_srcdir}/style.css
)

set(SOURCE_FILES
    ${CSS_SRCS}
)

set(SOURCE_PP_FILES
    alt1-c.css.in
    alt1-cgi.css.in
    alt1-cpp.css.in
    alt1-idl.css.in
    alt1-mk.css.in
    alt1-pl.css.in
    alt1-pm.css.in
    alt2-cgi.css.in
    alt2-pl.css.in
    alt2-pm.css.in
    cgi.css.in
    h.css.in
    idl.css.in
    pl.css.in
    pm.css.in
)

COPY_TO_DIST("${SOURCE_FILES}")
COMMON_PREPROCESS("${SOURCE_PP_FILES}")