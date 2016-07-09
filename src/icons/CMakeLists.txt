build_macro_mkPaths()
FIND_FINAL_TARGET()

Set(GIF_SRCS
    ${mk_srcdir}/back.gif
    ${mk_srcdir}/broken.gif
    ${mk_srcdir}/c.gif
    ${mk_srcdir}/folder.gif
    ${mk_srcdir}/forward.gif
    ${mk_srcdir}/generic.sec.gif
    ${mk_srcdir}/image2.gif
    ${mk_srcdir}/text.gif
)

set(SOURCE_FILES
    ${GIF_SRCS}
)

COPY_TO_DIST("${SOURCE_FILES}")