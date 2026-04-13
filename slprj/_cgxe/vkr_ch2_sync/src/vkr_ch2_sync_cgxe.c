/* Include files */

#include "vkr_ch2_sync_cgxe.h"
#include "m_IIhrosY5dKVXC9G7DfMuRB.h"

unsigned int cgxe_vkr_ch2_sync_method_dispatcher(SimStruct* S, int_T method,
  void* data)
{
  if (ssGetChecksum0(S) == 2348595039 &&
      ssGetChecksum1(S) == 3358373219 &&
      ssGetChecksum2(S) == 1206376296 &&
      ssGetChecksum3(S) == 159016202) {
    method_dispatcher_IIhrosY5dKVXC9G7DfMuRB(S, method, data);
    return 1;
  }

  return 0;
}
