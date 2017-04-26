build_macro_mkPaths()
FIND_FINAL_TARGET()

set(JS_SRCS
    ${mk_srcdir}/coloration.js
    ${mk_srcdir}/script.js
)

set(SOURCE_FILES
    ${JS_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")
