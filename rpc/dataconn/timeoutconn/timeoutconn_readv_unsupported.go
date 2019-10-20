// +build illumos solaris

package timeoutconn

import (
	"fmt"
	"syscall"
)

func (c Conn) readv(rawConn syscall.RawConn, iovecs []syscall.Iovec) (n int64, err error) {
	return 0, fmt.Errorf("Go does not support SYS_READV on this platform")
}
