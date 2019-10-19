#!/bin/bash
#
# Thanks to Tkkg1994 and djb77 for the script
#
# MoRoKernel Build Script
#

# SETUP
# -----
export ARCH=arm64
export SUBARCH=arm64
export BUILD_CROSS_COMPILE=/home/svirusx/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export CROSS_COMPILE=$BUILD_CROSS_COMPILE
export BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`

RDIR=$(pwd)
OUTDIR=$RDIR/arch/$ARCH/boot
DTSDIR=$RDIR/arch/$ARCH/boot/dts
DTBDIR=$OUTDIR/dtb
DTCTOOL=$RDIR/scripts/dtc/dtc
INCDIR=$RDIR/include
PAGE_SIZE=2048
DTB_PADDING=0

DEFCONFIG=moro_defconfig
DEFCONFIG_OREO=moro-oreo_defconfig
DEFCONFIG_PIE=moro-pie_defconfig
DEFCONFIG_S7EDGE=moro-edge_defconfig
DEFCONFIG_S7FLAT=moro-flat_defconfig


K_VERSION="v1.2"
K_SUBVER="4"
K_BASE="CSF1"
K_NAME="Nethunter_WirusMOD"
export KBUILD_BUILD_VERSION="1"


#
# FUNCTIONS
# ---------
FUNC_DELETE_PLACEHOLDERS()
{
	find . -name \.placeholder -type f -delete
        echo "Placeholders Deleted from Ramdisk"
        echo ""
}

FUNC_CLEAN_DTB()
{
	if ! [ -d $DTSDIR ] ; then
		echo "no directory : "$DTSDIR""
	else
		echo "rm files in : "$RDIR/arch/$ARCH/boot/dts/*.dtb""
		rm $DTSDIR/*.dtb 2>/dev/null
		rm $DTBDIR/*.dtb 2>/dev/null
		rm $OUTDIR/boot.img-dt 2>/dev/null
		rm $OUTDIR/boot.img-zImage 2>/dev/null
	fi
}

FUNC_BUILD_KERNEL()
{
	echo ""
	echo "Model: $MODEL"
	echo "OS: $OS"
        echo "build common config="$DEFCONFIG""
        echo "build variant config="$DEVICE_DEFCONFIG""

	cp -f $RDIR/arch/$ARCH/configs/$DEFCONFIG $RDIR/arch/$ARCH/configs/tmp_defconfig
	cat $RDIR/arch/$ARCH/configs/$OS_DEFCONFIG >> $RDIR/arch/$ARCH/configs/tmp_defconfig
	cat $RDIR/arch/$ARCH/configs/$DEVICE_DEFCONFIG >> $RDIR/arch/$ARCH/configs/tmp_defconfig

	if [ $OS == "lineage16" ] || [ $OS == "lineage17" ] || [ $OS == "treblePie" ]; then
		sed -i 's/CONFIG_USB_ANDROID_SAMSUNG_MTP=y/# CONFIG_USB_ANDROID_SAMSUNG_MTP is not set/g' $RDIR/arch/$ARCH/configs/tmp_defconfig
	fi
	
	if [ $GPU == "r28" ]; then
		sed -i 's/CONFIG_MALI_R22P0=y/# CONFIG_MALI_R22P0 is not set/g' $RDIR/arch/$ARCH/configs/tmp_defconfig
		sed -i 's/# CONFIG_MALI_R28P0 is not set/CONFIG_MALI_R28P0=y/g' $RDIR/arch/$ARCH/configs/tmp_defconfig
	fi
	

	#FUNC_CLEAN_DTB

	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			tmp_defconfig || exit -1
	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
	echo ""

	rm -f $RDIR/arch/$ARCH/configs/tmp_defconfig
}

FUNC_BUILD_DTB()
{
	[ -f "$DTCTOOL" ] || {
		echo "You need to run ./build.sh first!"
		exit 1
	}
	case $MODEL in
	G930)
		if [ $OS == "treblePie" ]; then
			DTSFILES="exynos8890-herolte_eur_open_treble_04 exynos8890-herolte_eur_open_treble_08
				exynos8890-herolte_eur_open_treble_09 exynos8890-herolte_eur_open_treble_10"

		elif [ $OS == "lineage16" ] || [ $OS == "lineage17" ]; then
			DTSFILES="exynos8890-herolte_eur_open_lineage_04 exynos8890-herolte_eur_open_lineage_08
				exynos8890-herolte_eur_open_lineage_09 exynos8890-herolte_eur_open_lineage_10"

		else
			DTSFILES="exynos8890-herolte_eur_open_04 exynos8890-herolte_eur_open_08
				exynos8890-herolte_eur_open_09 exynos8890-herolte_eur_open_10"
		fi
		;;
	G935)
		if [ $OS == "treblePie" ]; then
			DTSFILES="exynos8890-hero2lte_eur_open_treble_04 exynos8890-hero2lte_eur_open_treble_08"

		elif [ $OS == "lineage16" ] || [ $OS == "lineage17" ]; then
			DTSFILES="exynos8890-hero2lte_eur_open_lineage_04 exynos8890-hero2lte_eur_open_lineage_08"

		else
			DTSFILES="exynos8890-hero2lte_eur_open_04 exynos8890-hero2lte_eur_open_08"
		fi
		;;
	*)

		echo "Unknown device: $MODEL"
		exit 1
		;;
	esac
	mkdir -p $OUTDIR $DTBDIR
	cd $DTBDIR || {
		echo "Unable to cd to $DTBDIR!"
		exit 1
	}
	rm -f ./*
	echo "Processing dts files."
	for dts in $DTSFILES; do
		echo "=> Processing: ${dts}.dts"
		${CROSS_COMPILE}cpp -nostdinc -undef -x assembler-with-cpp -I "$INCDIR" "$DTSDIR/${dts}.dts" > "${dts}.dts"
		echo "=> Generating: ${dts}.dtb"
		$DTCTOOL -p $DTB_PADDING -i "$DTSDIR" -O dtb -o "${dts}.dtb" "${dts}.dts"
	done
	echo "Generating dtb.img."
	$RDIR/scripts/dtbtool_exynos/dtbtool -o "$OUTDIR/dtb.img" -d "$DTBDIR/" -s $PAGE_SIZE
	echo "Done."
}

FUNC_BUILD_RAMDISK()
{
	echo ""
	echo "Building Ramdisk"

		
	cd $RDIR/build
	mkdir temp 2>/dev/null
	cp -rf aik/. temp
	
	if [ $OS == "lineage17" ]; then
		cp -rf ramdisk/lineage17/ramdisk/. temp/ramdisk
		cp -rf ramdisk/lineage17/split_img/. temp/split_img
		rm -f temp/split_img/boot.img-zImage
		rm -f temp/split_img/boot.img-dt
		mv $RDIR/arch/$ARCH/boot/Image temp/split_img/boot.img-zImage
		mv $RDIR/arch/$ARCH/boot/dtb.img temp/split_img/boot.img-dt
		cd temp

	elif [ $OS == "lineage16" ]; then
		cp -rf ramdisk/lineage16/ramdisk/. temp/ramdisk
		cp -rf ramdisk/lineage16/split_img/. temp/split_img
		rm -f temp/split_img/boot.img-zImage
		rm -f temp/split_img/boot.img-dt
		mv $RDIR/arch/$ARCH/boot/Image temp/split_img/boot.img-zImage
		mv $RDIR/arch/$ARCH/boot/dtb.img temp/split_img/boot.img-dt
		cd temp

	elif [ $OS == "treblePie" ]; then
		cp -rf ramdisk/treblePie/ramdisk/. temp/ramdisk
		cp -rf ramdisk/treblePie/split_img/. temp/split_img
		rm -f temp/split_img/boot.img-zImage
		rm -f temp/split_img/boot.img-dt
		mv $RDIR/arch/$ARCH/boot/Image temp/split_img/boot.img-zImage
		mv $RDIR/arch/$ARCH/boot/dtb.img temp/split_img/boot.img-dt
		cd temp
	
	else
		cp -rf ramdisk/$OS/. temp/ramdisk
		cp -rf ramdisk/split_img/. temp/split_img
		rm -f temp/split_img/boot.img-zImage
		rm -f temp/split_img/boot.img-dt
		mv $RDIR/arch/$ARCH/boot/Image temp/split_img/boot.img-zImage
		mv $RDIR/arch/$ARCH/boot/dtb.img temp/split_img/boot.img-dt
		cd temp

		if [ $MODEL == "G930" ]; then
			sed -i 's/SRPOI30A003KU/SRPOI17A003KU/g' split_img/boot.img-board

			sed -i 's/G935/G930/g' ramdisk/default.prop
			sed -i 's/hero2/hero/g' ramdisk/default.prop
			if [ $OS == "tw" ]; then 
				sed -i 's/G935/G930/g' ramdisk/sepolicy_version
			fi
		fi

		if [ $OS == "twPie" ]; then
			sed -i 's/8.0.0/9.0.0/g' split_img/boot.img-osversion
		fi
	fi

	echo "Model: $MODEL, OS: $OS"

	./repackimg.sh

	echo SEANDROIDENFORCE >> image-new.img
	mkdir $RDIR/build/kernel-temp 2>/dev/null
	mv image-new.img $RDIR/build/kernel-temp/$MODEL-$OS-$GPU-boot.img
	rm -rf $RDIR/build/temp

}

FUNC_BUILD_FLASHABLES()
{
	cd $RDIR/build
	mkdir temp
	cp -rf zip/common/. temp
	
	cd $RDIR/build/kernel-temp
	echo ""
	echo "Compressing kernels..."
	tar cv * | xz -9 > ../temp/moro/kernel.tar.xz

	cd $RDIR/build/temp
	zip -9 -r ../$ZIP_NAME *

	cd ..
	rm -rf temp kernel-temp ramdisk-temp
}


#
# MAIN PROGRAM
# ------------

MAIN()
{

if [ $OS == "twPie" ] || [ $OS == "treblePie" ]; then
	export ANDROID_MAJOR_VERSION=p
	export ANDROID_VERSION=90000
	export BUILD_PLATFORM_VERSION=9.0.0
else
	export ANDROID_MAJOR_VERSION=o
	export ANDROID_VERSION=80000
	export BUILD_PLATFORM_VERSION=8.0.0
fi

export KERNEL_VERSION="$K_SUBVER-$K_NAME-$OS-$K_BASE-$K_VERSION"

(
	START_TIME=`date +%s`
	FUNC_DELETE_PLACEHOLDERS
	FUNC_BUILD_KERNEL
	FUNC_BUILD_DTB
	FUNC_BUILD_RAMDISK
	if [ $ZIP == "yes" ]; then
	    FUNC_BUILD_FLASHABLES
	fi
	END_TIME=`date +%s`
	let "ELAPSED_TIME=$END_TIME-$START_TIME"
	echo "Total compile time is $ELAPSED_TIME seconds"
	echo ""
) 2>&1 | tee -a ./$MODEL-$OS-build.log

	echo "Your flasheable release can be found in the build folder"
	echo ""
}


#
# PROGRAM START
# -------------
clear
echo "***********************"
echo "MoRoKernel Build Script"
echo "***********************"
echo ""
echo ""
echo "Build Kernel for:"
echo ""
echo "Only S7 EDGE G935"
echo "(1) S7 Edge - Samsung OREO"
echo "(2) S7 Edge - Samsung PIE (r28)"
echo "(3) S7 Edge - Lineage 16"
echo "(4) S7 Edge - Lineage 17"
echo "(5) S7 Edge - TREBLE PIE"
echo ""
echo "S7 AllInOne: OREO + PIE + Lineage + Treble"
echo "(6) S7 AllInOne: OREO + PIE + AOSP"
echo ""
echo "**************************************"
echo ""
read -p "Select an option to compile the kernel " prompt
echo ""


if [ $prompt == "1" ]; then

    echo "S7 - Samsung OREO Selected"

    OS=twOreo
    K_OS=OREO
    GPU=r22
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=yes
    ZIP_NAME=$K_NAME-$OS-$MODEL-$K_BASE-$K_VERSION.zip
    MAIN
	
elif [ $prompt == "2" ]; then

    echo "S7 - Samsung PIE Selected (r28)"

    OS=twPie
    K_OS=PIE
    GPU=r28
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=yes
    ZIP_NAME=$K_NAME-$OS-$MODEL-$K_BASE-$K_VERSION.zip
    MAIN
	
elif [ $prompt == "3" ]; then

    echo "S7 Edge - Lineage 16 Selected"

    OS=lineage16
    K_OS=PIE
    GPU=r22
    MODEL=G935
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7EDGE
    ZIP=yes
    ZIP_NAME=$K_NAME-$OS-$MODEL-$K_BASE-$K_VERSION.zip
    MAIN

elif [ $prompt == "4" ]; then

    echo "S7 Edge - Lineage 17 Selected"

    OS=lineage17
    K_OS=PIE
    GPU=r22
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=yes
    ZIP_NAME=$K_NAME-$OS-$MODEL-$K_BASE-$K_VERSION.zip
    MAIN
    
elif [ $prompt == "5" ]; then

    echo "S7 - TREBLE PIE Selected"

    OS=treblePie
    K_OS=PIE
    GPU=r28
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=yes
    ZIP_NAME=$K_NAME-$OS-$MODEL-$K_BASE-$K_VERSION.zip
    MAIN

elif [ $prompt == "6" ]; then

    echo "S7 AllInOne: OREO + PIE + AOSP"

    OS=twOreo
    K_OS=OREO
    GPU=r22
    MODEL=G935
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7EDGE
    ZIP=no
    MAIN

    OS=twOreo
    K_OS=OREO
    GPU=r22
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=no
    MAIN

    OS=twPie
    K_OS=PIE
    GPU=r28
    MODEL=G935
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7EDGE
    ZIP=no
    MAIN

    OS=twPie
    K_OS=PIE
    GPU=r28
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=no
    MAIN
    
    OS=twPie
    K_OS=PIE
    GPU=r22
    MODEL=G935
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7EDGE
    ZIP=no
    MAIN

    OS=twPie
    K_OS=PIE
    GPU=r22
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=no
    MAIN

    OS=lineage16
    K_OS=PIE
    GPU=r22
    MODEL=G935
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7EDGE
    ZIP=no
    MAIN

    OS=lineage16
    K_OS=PIE
    GPU=r22
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=no
    MAIN

    OS=lineage17
    K_OS=PIE
    GPU=r22
    MODEL=G935
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7EDGE
    ZIP=no
    MAIN

    OS=lineage17
    K_OS=PIE
    GPU=r22
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_OREO
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=no
    MAIN
    
    OS=treblePie
    K_OS=PIE
    GPU=r28
    MODEL=G935
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7EDGE
    ZIP=no
    MAIN
    
    OS=treblePie
    K_OS=PIE
    GPU=r28
    MODEL=G930
    OS_DEFCONFIG=$DEFCONFIG_PIE
    DEVICE_DEFCONFIG=$DEFCONFIG_S7FLAT
    ZIP=yes
    ZIP_NAME=$K_NAME-AllInOne-$K_BASE-$K_VERSION.zip
    MAIN

fi





