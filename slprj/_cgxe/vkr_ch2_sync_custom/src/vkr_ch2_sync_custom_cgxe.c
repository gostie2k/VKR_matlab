/* Include files */

#include "vkr_ch2_sync_custom_cgxe.h"
#include "m_9MWhQqZJcki6kz2gGc1zrF.h"

unsigned int cgxe_vkr_ch2_sync_custom_method_dispatcher(SimStruct* S, int_T
  method, void* data)
{
  if (ssGetChecksum0(S) == 3570842758 &&
      ssGetChecksum1(S) == 1527258843 &&
      ssGetChecksum2(S) == 645881121 &&
      ssGetChecksum3(S) == 1181785031) {
    method_dispatcher_9MWhQqZJcki6kz2gGc1zrF(S, method, data);
    return 1;
  }

  return 0;
}
