build_macro_mkPaths()
FIND_FINAL_TARGET()

set(PERL_SRCS
    ${mk_srcdir}/Config.pm
    ${mk_srcdir}/Shell.pm
)

set(SOURCE_FILES
    ${PERL_SRCS}
)

build_func_preprocess(
    Common.pm.in
    ${FINAL_TARGET}/Common.pm
    ${varBuildDefines}
    -DXREF_TARGET="moonchild"
    --marker %
)

COPY_TO_DIST("${SOURCE_FILES}")