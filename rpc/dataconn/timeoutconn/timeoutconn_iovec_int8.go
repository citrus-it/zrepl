// +build illumos solaris

package timeoutconn

import (
	"syscall"
	"unsafe"
)

func makeIovec(byteVec []byte) syscall.Iovec {
	v := syscall.Iovec{
		Base: (*int8)(unsafe.Pointer(&byteVec[0])),
	}
	// syscall.Iovec.Len has platform-dependent size, thus use SetLen
	v.SetLen(len(byteVec))
	return v
}
