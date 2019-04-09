#ifndef utils_h
#define utils_h

#include <Foundation/Foundation.h>

void setGID(gid_t gid, uint64_t proc);
void setUID (uid_t uid, uint64_t proc);
uint64_t selfproc(void);
void rootMe (int both, uint64_t proc);
void unsandbox (uint64_t proc);

#endif
