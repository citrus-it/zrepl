# Repo Administration

assuming singing key is 20612ECF43C34D3955C84DCAE294BF5B7EF47006

aptly repo create zrepl-stable

aptly publish repo -gpg-key='20612ECF43C34D3955C84DCAE294BF5B7EF47006' -distribution=buster zrepl-stable


run `aptly serve`

# Routine (every build)

```bash
# produce binary release with zrepl's build system
make release

# add debian/changelog entry (repo is zrepl-stable)

# build packages:
dpkg-buildpackage --build=binary --no-sign --host-arch amd64
dpkg-buildpackage --build=binary --no-sign --host-arch arm64

# add to aplty repo
cd ..
aptly repo include -accept-unsigned *.changes
```
