#! /usr/bin/env bash

COMPILER="$1"
KERNEL_VERSION="$2"
KERNELSU_REPO="$3"
KERNELSU_BRANCH="$4"
ACK="https://android.googlesource.com/kernel/common"

fetch_kernel() {
	git clone --depth=1 $ACK -b $1 $2
}

setup_kernelsu() {
	GKI_ROOT=$(pwd)
	DRIVER_DIR="$GKI_ROOT/drivers"
	DRIVER_MAKEFILE="$DRIVER_DIR/Makefile"
	DRIVER_KCONFIG="$DRIVER_DIR/Kconfig"

	echo "[+] Setting up KernelSU..."
	test -d "$GKI_ROOT/KernelSU" || git clone $1 KernelSU && echo "[+] Repository cloned."
	cd "$GKI_ROOT/KernelSU"
	git switch $2
	cd "$DRIVER_DIR"
	ln -sf "$(realpath --relative-to="$DRIVER_DIR" "$GKI_ROOT/KernelSU/kernel")" "kernelsu" && echo "[+] Symlink created."

	# Add entries in Makefile and Kconfig if not already existing
	grep -q "kernelsu" "$DRIVER_MAKEFILE" || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE" && echo "[+] Modified Makefile."
	grep -q "source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" || sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" && echo "[+] Modified Kconfig."
	echo '[+] Done.'
	cd ..
}

[ -z $COMPILER ] && exit 1;
[ -z $KERNEL_VERSION ] && exit 1;
[ -z $KERNELSU_REPO ] && exit 1;
[ -z $KERNELSU_BRANCH ] && exit 1;

if [ "$COMPILER" == "llvm" ]; then
	curl -LSs "https://raw.githubusercontent.com/rsuntk/toolchains/refs/heads/README/clone.sh" | bash -s clang-11
	# just in case it would need clang triple
	curl -LSs "https://raw.githubusercontent.com/rsuntk/toolchains/refs/heads/README/clone.sh" | bash -s gcc-6.4
elif [ "$COMPILER" == "gcc" ]; then
	curl -LSs "https://raw.githubusercontent.com/rsuntk/toolchains/refs/heads/README/clone.sh" | bash -s gcc-6.4
fi

KDIR="kernel_$KERNEL_VERSION"
if [ "$KERNEL_VERSION" == "54" ]; then
	fetch_kernel android12-5.4-lts $KDIR
elif [ "$KERNEL_VERSION" == "419" ]; then
	fetch_kernel deprecated/android-4.19-stable $KDIR
elif [ "$KERNEL_VERSION" == "414" ]; then
	fetch_kernel deprecated/android-4.14-stable $KDIR
elif [ "$KERNEL_VERSION" == "49" ]; then
	fetch_kernel deprecated/android-4.9-q $KDIR
elif [ "$KERNEL_VERSION" == "44" ]; then
	fetch_kernel deprecated/android-4.4-p $KDIR
fi

echo -e "\n\n DIR: $(pwd)\n\n"

export ARCH=arm64
export CROSS_COMPILE=$(pwd)/gcc-6.4/bin/aarch64-linux-gnu-
export CLANG_TRIPLE=$CROSS_COMPILE
export PATH=$(pwd)/clang-11/bin:$PATH

if [ "$COMPILER" == "llvm" ]; then
if [ "$KERNEL_VERSION" == "419" ] || [ "$KERNEL_VERSION" == "54" ]; then
	export LLVM=1
	export LLVM_IAS=1
fi
fi

cd $KDIR && setup_kernelsu $KERNELSU_REPO $KERNELSU_BRANCH

make defconfig -j$(nproc --all)
make -j$(nproc --all)