build_macro_mkPaths()
FIND_FINAL_TARGET()

set(ALL_SRCS
    ${mk_srcdir}/robots.txt
)

set(SOURCE_FILES
    ${ALL_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")