/**
 */
void test1()
{
  if (unrecognized_func_call(name) == 0))) {
goto EXIT;
  }
}

void recognized_function(){}

void test2()
{
  if ((func_call() ) ) {
goto EXIT;
  }
}

void recognized_function2(){}

void test3()
{
  if ((func_call() ) ) {
  }
}

void recognized_function3(){}

void broken_funct1()
{
  if ((func_call())) {
  }
}

void recognized_function4() {}

void ok_funct2()
{
  if ((func_call()==0 ) ) {
  }
}

void recognized_function5() {}

void broken_funct2()
{
  if ((func_call()==0)) {
goto EXIT;
  }
}

void unrecognized_function1() {}

