// +build !illumos
// +build !solaris

package timeoutconn

import "syscall"

func makeIovec(byteVec []byte) syscall.Iovec {
	v := syscall.Iovec{
		Base: &byteVec[0],
	}
	// syscall.Iovec.Len has platform-dependent size, thus use SetLen
	v.SetLen(len(byteVec))
	return v
}
