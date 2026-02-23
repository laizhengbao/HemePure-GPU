#!/bin/sh

set -e

usage(){
	printf "%s [VARIENT | --help]\n" "$1"
	printf "VARIENT:\n"
	printf "\tPP:\t\tPressure-Pressure BCs\n"
	printf "\tVP:\t\tVelocity-Pressure BCs\n"
	printf "\tany other:\t\tthe default\n"
}

MODULES(){
	# you might need to put these in env.sh for efficiency
	if module avail > /dev/null 2> /dev/null
	then
		module purge

		# TWCC
		module load nvhpc-24.11_hpcx-2.20_cuda-12.6
		module load gcc10/10.2.1

	else
		echo "No modules, skipping loading"
	fi

	export CC=mpicc
	export CXX=mpicxx

	export OMPI_CC=gcc
	export OMPI_CXX=g++
	export OMPI_FC=gfortran

	export CUVER=70
	export CUDA_GRAPH=""
}

DEPbuild(){

	if [ -d dep/build ]
	then
		return 0
	fi

	echo ""
	echo "Start building dependencies..."
	echo ""

	cmake -B dep/build dep --fresh \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER="${CC}" \
		-DCMAKE_CXX_COMPILER="${CXX}" \
		-DCMAKE_C_FLAGS="-O3 -g" \
		-DCMAKE_CXX_FLAGS="-O3 -g" \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON
	cmake --build dep/build -j
	# -j 1 if something went wrong

	echo ""
	echo "Done building dependencies"
	echo ""

}

SRCbuild(){

	VARIENT="$1"

	echo ""
	printf "Start building src with varient '%s'\n" "$VARIENT"
	echo ""

	set --

	case "$VARIENT"
	in
		"PP")
		set -- "$@" \
			-DHEMELB_USE_VELOCITY_WEIGHTS_FILE=OFF \
			-DHEMELB_INLET_BOUNDARY=NASHZEROTHORDERPRESSUREIOLET \
			-DHEMELB_WALL_INLET_BOUNDARY=NASHZEROTHORDERPRESSURESBB \
			-DHEMELB_OUTLET_BOUNDARY=NASHZEROTHORDERPRESSUREIOLET \
			-DHEMELB_WALL_OUTLET_BOUNDARY=NASHZEROTHORDERPRESSURESBB
		;;
		"VP")
		set -- "$@" \
			-DHEMELB_USE_VELOCITY_WEIGHTS_FILE=ON \
			-DHEMELB_INLET_BOUNDARY=LADDIOLET \
			-DHEMELB_WALL_INLET_BOUNDARY=LADDIOLETSBB \
			-DHEMELB_OUTLET_BOUNDARY=NASHZEROTHORDERPRESSUREIOLET \
			-DHEMELB_WALL_OUTLET_BOUNDARY=NASHZEROTHORDERPRESSURESBB \
		;;
		*)
		;;
	esac

	if [ -z "${CUDA_GRAPH}" ]
	then
		set -- "$@" \
			-DHEMELB_USE_CUDA_GRAPH=OFF \
			-DCMAKE_CUDA_FLAGS="--maxrregcount=64 --ptxas-options=-v"
	fi

	INSTALL_DIR="$(pwd)/hemelabgpu${VARIENT:+-${VARIENT}}"

	if [ -d "${INSTALL_DIR}" ]
	then
		rm -rf "${INSTALL_DIR}"
	fi

	# NVC doesn't support cmake ipo detection
	# and we shall not use -Mipa=fast, it would cause seg fault
	# sm70 for V100

	cmake -B src/build src \
		--install-prefix="${INSTALL_DIR}" \
		--fresh \
		-DHEMELB_GPU_BACKEND=CUDA \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER="${CC}" \
		-DCMAKE_CXX_COMPILER="${CXX}" \
		-DCMAKE_CUDA_ARCHITECTURES="${CUVER}" \
		\
		-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
		-DCMAKE_SKIP_BUILD_RPATH=FALSE \
		-DCMAKE_INSTALL_RPATH="${INSTALL_DIR}/lib" \
		-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
		\
		-DHEMELB_USE_PARMETIS=ON \
		-DHEMELB_USE_MPI_CALL=ON \
		-DHEMELB_ALLTOALL_IMPLEMENTATION="Separated" \
		-DHEMELB_GATHERS_IMPLEMENTATION="Separated" \
		-DHEMELB_POINTPOINT_IMPLEMENTATION="Coalesce" \
		\
		-DHEMELB_USE_SSE3=OFF \
		\
		-DHEMELB_OPTIMISATION="-O3 -g" \
		"$@"
	cmake --build src/build -j
	cmake --install src/build

	echo ""
	printf "Done building src with varient '%s'\n" "$VARIENT"
	echo ""

}

if [ "$1" = "--help" ]
then
	usage "$0"
fi

MODULES
DEPbuild
SRCbuild "$1"
