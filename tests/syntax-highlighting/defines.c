#define DEFINED
#define VALUE 1
#define FUNCTION() {}
#define FUNC_WITH_(arg) {arg;}
#define UNDEFED 10
#undef UNDEFED

void
quible(void) {
int q = DEFINED VALUE DEFINED;
FUNCTION();
FUNC_WITH_(q++);
UNDEFED
}
