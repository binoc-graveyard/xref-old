#include "prop.h"

class props : testInterface
{
  NS_DECL_TESTINTERFACE
} 

NS_IMETHODIMP
props::GetReadableFoo(PRBool *aFoo)
{
  return NS_OK;
}

NS_IMETHODIMP
props::SetWritableBar(PRBool aFoo)
{
  return NS_OK;
}

NS_IMETHODIMP
props::GetWritableBar(PRBool *aFoo)
{
  return NS_OK;
}

NS_IMETHODIMP
props::LongMethod()
{
  return NS_OK;
}
