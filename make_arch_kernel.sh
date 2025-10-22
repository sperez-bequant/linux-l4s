#!/bin/bash

scripts/setlocalversion --save-scmversion
echo -l4s-debug > localversion.10-pkgname

if [ -f /proc/config.gz ]; then
    zcat /proc/config.gz > .config
else
    curl -LSso .config https://github.com/archlinux/svntogit-packages/raw/packages/linux/trunk/config
fi

make -j"$(nproc)" olddefconfig

scripts/config -m TCP_CONG_PRAGUE
scripts/config -m NET_SCH_DUALPI2
scripts/config -m TCP_CONG_DCTCP
scripts/config -m TCP_CONG_BBR2


./scripts/config --enable CONFIG_FB
./scripts/config --enable CONFIG_FB_SIMPLE
./scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE
./scripts/config --enable CONFIG_VT
./scripts/config --enable CONFIG_VT_CONSOLE
./scripts/config --enable CONFIG_DUMMY_CONSOLE
./scripts/config --enable CONFIG_DRM_VBOXVIDEO

make -s kernelrelease >version

make -j"$(nproc)" bzImage && make -j"$(nproc)" modules

pkgroot="$HOME/tmp/linux-pkgbuild"
rm -rf "${pkgroot}"
mkdir -p "${pkgroot}"
cat > "${pkgroot}/PKGBUILD" <<'EOF'
pkgname=linux-l4s-debug
pkgver=0
pkgrel=1
arch=(x86_64)
license=(GPL2)
options=('!strip')

package() {
  pkgdesc="The Linux kernel and modules"
  depends=(coreutils kmod initramfs)
  optdepends=('crda: to set the correct wireless channels of your country'
              'linux-firmware: firmware images needed for some devices')
  provides=(VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE)
  replaces=(virtualbox-guest-modules-arch wireguard-arch)

  local pkgroot="${pkgdir//\/pkg\/$pkgname/}"
  rm -rf "$pkgroot"/pkg
  cp -rv "$pkgroot"/pkg-ext "$pkgroot"/pkg
}

# vim:set ts=8 sts=2 sw=2 et:
EOF

pkg="linux-l4s-debug"
pkgdir="${pkgroot}/pkg-ext/${pkg}"
modulesdir="${pkgdir}/usr/lib/modules/$(<version)"

install -Dm644 "$(make -s image_name)" "${modulesdir}/vmlinuz"

echo "${pkg}" | install -Dm644 /dev/stdin "${modulesdir}/pkgbase"

make -j"$(nproc)" DEPMOD=/doesnt/exist INSTALL_MOD_PATH="${pkgdir}/usr" INSTALL_MOD_STRIP=1 modules_install

rm "${modulesdir}"/{build,source}
commit=$(git rev-parse --short HEAD)
sed -i "s/pkgver=.*/pkgver=${commit}/g" "${pkgroot}/PKGBUILD"
cd "${pkgroot}"
makepkg -R

