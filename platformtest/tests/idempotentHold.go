package tests

import (
	"fmt"

	"github.com/zrepl/zrepl/platformtest"
	"github.com/zrepl/zrepl/zfs"
)

func IdempotentHold(ctx *platformtest.Context) {

	platformtest.Run(ctx, platformtest.PanicErr, ctx.RootDataset, `
		DESTROYROOT
		CREATEROOT
		+  "foo bar"
		+  "foo bar@1"
	`)
	defer platformtest.Run(ctx, platformtest.PanicErr, ctx.RootDataset, `
		R zfs release zrepl_platformtest "${ROOTDS}/foo bar@1"
		-  "foo bar@1"
		-  "foo bar"
	`)

	fs := fmt.Sprintf("%s/foo bar", ctx.RootDataset)
	tag := "zrepl_platformtest"
	err := zfs.ZFSHold(ctx, fs, "1", tag)
	if err != nil {
		panic(err)
	}

	err = zfs.ZFSHold(ctx, fs, "1", tag)
	if err != nil {
		panic(err)
	}

	err = zfs.ZFSHold(ctx, fs, "nonexistent", tag)
	if err == nil {
		panic("still expecting error for nonexistent snapshot")
	}

}
