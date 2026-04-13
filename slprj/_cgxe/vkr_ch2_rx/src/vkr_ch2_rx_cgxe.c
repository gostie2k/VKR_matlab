/* Include files */

#include "vkr_ch2_rx_cgxe.h"
#include "m_pVxNbHg3pjrmldTuWGNJlG.h"

unsigned int cgxe_vkr_ch2_rx_method_dispatcher(SimStruct* S, int_T method, void*
  data)
{
  if (ssGetChecksum0(S) == 2658261197 &&
      ssGetChecksum1(S) == 3668002792 &&
      ssGetChecksum2(S) == 3169634247 &&
      ssGetChecksum3(S) == 1866227799) {
    method_dispatcher_pVxNbHg3pjrmldTuWGNJlG(S, method, data);
    return 1;
  }

  return 0;
}
