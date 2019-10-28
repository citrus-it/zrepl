.PHONY: generate build test vet cover release docs docs-clean clean format lint platformtest
.DEFAULT_GOAL := build

ARTIFACTDIR := artifacts

ifdef ZREPL_VERSION
    _ZREPL_VERSION := $(ZREPL_VERSION)
endif
ifndef _ZREPL_VERSION
    _ZREPL_VERSION := $(shell git describe --always --dirty 2>/dev/null || echo "ZREPL_BUILD_INVALID_VERSION" )
    ifeq ($(_ZREPL_VERSION),ZREPL_BUILD_INVALID_VERSION) # can't use .SHELLSTATUS because Debian Stretch is still on gmake 4.1
        $(error cannot infer variable ZREPL_VERSION using git and variable is not overriden by make invocation)
    endif
endif

GO := go
GOOS ?= $(shell bash -c 'source <($(GO) env) && echo "$$GOOS"')
GOARCH ?= $(shell bash -c 'source <($(GO) env) && echo "$$GOARCH"')
GO_ENV_VARS := GO111MODULE=on
GO_LDFLAGS := "-X github.com/zrepl/zrepl/version.zreplVersion=$(_ZREPL_VERSION)"
GO_MOD_READONLY := -mod=readonly
GO_BUILDFLAGS := $(GO_MOD_READONLY)
GO_BUILD := $(GO_ENV_VARS) $(GO) build $(GO_BUILDFLAGS) -ldflags $(GO_LDFLAGS)

.PHONY: printvars
printvars:
	@echo GOOS=$(GOOS)
	@echo GOARCH=$(GOARCH)

.PHONY: release release-bins-all release-noarch
RELEASE_PER_ARCH_TARGETS := release-bin vet lint
release:
	$(MAKE) release-bins-all
	$(MAKE) $(RELEASE_NOARCH)
	$(MAKE) check-git-clean
release-bins-all:
	$(MAKE) release-bin vet lint GOOS=freebsd   GOARCH=amd64
	$(MAKE) release-bin vet lint GOOS=freebsd   GOARCH=386
	$(MAKE) release-bin vet lint GOOS=linux     GOARCH=amd64
	$(MAKE) release-bin vet lint GOOS=linux     GOARCH=arm64
	$(MAKE) release-bin vet lint GOOS=linux     GOARCH=386
	$(MAKE) release-bin vet lint GOOS=darwin    GOARCH=amd64
	$(MAKE) release-bin vet lint GOOS=illumos   GOARCH=amd64
	$(MAKE) release-bin vet lint GOOS=solaris   GOARCH=amd64

RELEASE_NOARCH := $(ARTIFACTDIR)/zrepl-noarch.tar
THIS_PLATFORM_RELEASE_BIN := $(shell bash -c 'source <($(GO) env) && echo "zrepl-$${GOOS}-$${GOARCH}"' )

generate: #not part of the build, must do that manually
	protoc -I=replication/logic/pdu --go_out=plugins=grpc:replication/logic/pdu replication/logic/pdu/pdu.proto
	$(GO_ENV_VARS) $(GO) generate $(GO_BUILDFLAGS) -x ./...

format:
	goimports -srcdir . -local 'github.com/zrepl/zrepl' -w $(shell find . -type f -name '*.go' -not -path "./vendor/*" -not -name '*.pb.go' -not -name '*_enumer.go')

lint:
	$(GO_ENV_VARS) golangci-lint run ./...

test:
	$(GO_ENV_VARS) $(GO) test $(GO_BUILDFLAGS) ./...

vet:
	$(GO_ENV_VARS) $(GO) vet $(GO_BUILDFLAGS) ./...

ZREPL_PLATFORMTEST_POOLNAME := zreplplatformtest
ZREPL_PLATFORMTEST_IMAGEPATH := /tmp/zreplplatformtest.pool.img
$(ARTIFACTDIR)/platformtest-$(GOOS)-$(GOARCH):
	$(GO_BUILD) -o "$@" ./platformtest/harness
platformtest: $(ARTIFACTDIR)/platformtest-$(GOOS)-$(GOARCH)
	"$(ARTIFACTDIR)/platformtest-$(GOOS)-$(GOARCH)" -poolname "$(ZREPL_PLATFORMTEST_POOLNAME)" -imagepath "$(ZREPL_PLATFORMTEST_IMAGEPATH)"

$(ARTIFACTDIR):
	mkdir -p "$@"

$(ARTIFACTDIR)/docs: $(ARTIFACTDIR)
	mkdir -p "$@"

$(ARTIFACTDIR)/bash_completion: release-bin
	artifacts/$(THIS_PLATFORM_RELEASE_BIN) bashcomp "$@"

.PHONY: $(ARTIFACTDIR)/go_env.txt
$(ARTIFACTDIR)/go_env.txt:
	$(GO_ENV_VARS) $(GO) env > $@

docs: $(ARTIFACTDIR)/docs
	make -C docs \
		html \
		BUILDDIR=../artifacts/docs \

docs-clean:
	make -C docs \
		clean \
		BUILDDIR=../artifacts/docs

.PHONY: release-bin
release-bin:
	$(GO_BUILD) -o "$(ARTIFACTDIR)/zrepl-$(GOOS)-$(GOARCH)"

$(RELEASE_NOARCH): docs $(ARTIFACTDIR)/bash_completion $(ARTIFACTDIR)/go_version.txt
	tar --mtime='1970-01-01' --sort=name \
		--transform 's/$(ARTIFACTDIR)/zrepl-$(_ZREPL_VERSION)-noarch/' \
		--transform 's#dist#zrepl-$(_ZREPL_VERSION)-noarch/dist#' \
		--transform 's#config/samples#zrepl-$(_ZREPL_VERSION)-noarch/config#' \
		-acf $@ \
		$(ARTIFACTDIR)/docs/html \
		$(ARTIFACTDIR)/bash_completion \
		$(ARTIFACTDIR)/go_version.txt \
		dist \
		config/samples

release-old: $(RELEASE_BINS) $(RELEASE_NOARCH)
	rm -rf "$(ARTIFACTDIR)/release"
	mkdir -p "$(ARTIFACTDIR)/release"
	cp $^ "$(ARTIFACTDIR)/release"
	cd "$(ARTIFACTDIR)/release" && sha512sum $$(ls | sort) > sha512sum.txt
	@# note that we use ZREPL_VERSION and not _ZREPL_VERSION because we want to detect the override
	@if git describe --always --dirty 2>/dev/null | grep dirty >/dev/null; then \
        echo '[INFO] either git reports checkout is dirty or git is not installed or this is not a git checkout'; \
		if [ "$(ZREPL_VERSION)" = "" ]; then \
			echo '[WARN] git checkout is dirty and make variable ZREPL_VERSION was not used to override'; \
			git status; \
			echo "git diff:";  \
			git diff | cat; \
			exit 1; \
		fi; \
	fi;

clean: docs-clean
	rm -rf "$(ARTIFACTDIR)"
