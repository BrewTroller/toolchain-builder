#!/bin/bash -ex
# Copyright (c) 2014-2015 Arduino LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# linux -   ./build.all.new.bash
# windows - ./build.all.new.bash -h=i686-w64-mingw32" 


export BINUTILS_VERSION=2.26.1
export GCC_VERSION=5.4.0
export ISL_VERSION=0.16
export CLOOG_VERSION=0.18.1
export GMP_VERSION=5.1.3
export MPFR_VERSION=3.1.3
export MPC_VERSION=1.0.3


for i in "$@"
do
case $i in
        -h=*|--host=*)
        export HOST="${i#*=}"
        ;;
        -p=*|--path=*)
        export PATH=$PATH:"${i#*=}"
        ;;
        -cc=*)
        export CC="${i#*=}"
        ;;
        -cxx=*)
        export CXX="${i#*=}"
        ;;
        -cflags=*)
        export CFLAGS="${i#*=}"
        ;;
        -cxxflags=*)
        export CXXFLAGS="${i#*=}"
        ;;
        -ldflags=*)
        export LDFLAGS="${i#*=}"
        ;;
        *)
        # unknown option
        ;;
esac
done

export home=`pwd`

#rm *.tar.*

if [ ! -f binutils-$BINUTILS_VERSION.tar.bz2 ]; then
wget ftp://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.bz2
fi
rm -rf binutils-$BINUTILS_VERSION
tar xf binutils-$BINUTILS_VERSION.tar.bz2
cd binutils-$BINUTILS_VERSION
curl -L https://projects.archlinux.org/svntogit/community.git/plain/trunk/avr-size.patch?h=packages/avr-binutils > 01-avr-size.patch
patch -Np0 < 01-avr-size.patch

sed -i -e "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" libiberty/configure

config_guess=`./config.guess`

if [ "x"$HOST == "x" ]; then
export HOST=${config_guess}
fi

export pkgdir=${home}/pkg-$HOST/

export pkgdir_build=${home}/pkg-${config_guess}/

./configure \
        --prefix=$pkgdir \
        --with-bugurl=https://github.com/arduino/toolchain-avr/ \
        --enable-gold \
        --enable-ld=default \
        --enable-plugins \
        --enable-threads \
        --with-pic \
        --enable-lto \
        --disable-shared \
        --disable-werror \
        --disable-multilib \
        --host=$HOST \
        --build=${config_guess} \
        --target=avr

make configure-host
make -j8

make install

cd $home

rm -rf gcc-$GCC_VERSION

if [ ! -f gcc-$GCC_VERSION.tar.bz2 ]; then
wget ftp://gcc.gnu.org/pub/gcc/releases/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.bz2
fi
if [ ! -f isl-$ISL_VERSION.tar.bz2 ]; then
wget http://isl.gforge.inria.fr/isl-$ISL_VERSION.tar.bz2
fi
if [ ! -f cloog-$CLOOG_VERSION.tar.gz ]; then
wget http://www.bastoul.net/cloog/pages/download/cloog-$CLOOG_VERSION.tar.gz
fi
if [ ! -f gmp-$GMP_VERSION.tar.bz2 ]; then
wget http://mirror.switch.ch/ftp/mirror/gnu/gmp/gmp-$GMP_VERSION.tar.bz2
fi
if [ ! -f mpfr-$MPFR_VERSION.tar.bz2 ]; then
wget http://mirror.switch.ch/ftp/mirror/gnu/mpfr/mpfr-$MPFR_VERSION.tar.bz2
fi
if [ ! -f mpc-$MPC_VERSION.tar.gz ]; then
wget http://www.multiprecision.org/mpc/download/mpc-$MPC_VERSION.tar.gz
fi

tar xf gcc-$GCC_VERSION.tar.bz2
tar xf isl-$ISL_VERSION.tar.bz2
tar xf cloog-$CLOOG_VERSION.tar.gz
tar xf gmp-$GMP_VERSION.tar.bz2
tar xf mpfr-$MPFR_VERSION.tar.bz2
tar xf mpc-$MPC_VERSION.tar.gz

rm -rf gcc-$GCC_VERSION/cloog gcc-$GCC_VERSION/isl gcc-$GCC_VERSION/gmp gcc-$GCC_VERSION/mpfr gcc-$GCC_VERSION/mpc

mv cloog-$CLOOG_VERSION gcc-$GCC_VERSION/cloog
mv isl-$ISL_VERSION gcc-$GCC_VERSION/isl
mv gmp-$GMP_VERSION gcc-$GCC_VERSION/gmp
mv mpfr-$MPFR_VERSION gcc-$GCC_VERSION/mpfr
mv mpc-$MPC_VERSION gcc-$GCC_VERSION/mpc

cd gcc-$GCC_VERSION/

sed -i -e "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" {libiberty,gcc}/configure

echo $GCC_VERSION > gcc/BASE-VER

export CFLAGS_FOR_TARGET='-O2 -pipe'
export CXXFLAGS_FOR_TARGET='-O2 -pipe'

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${pkgdir_build}/${config_guess}/avr/lib/
export PATH=$PATH:${pkgdir_build}/bin/

cd $home

rm -rf gcc-build
mkdir gcc-build && cd gcc-build

$home/gcc-$GCC_VERSION/configure \
                --disable-install-libiberty \
                --disable-libssp \
                --disable-libstdcxx-pch \
                --disable-libunwind-exceptions \
                --disable-nls \
                --enable-fixed-point \
                --enable-long-long \
                --disable-werror \
                --disable-__cxa_atexit \
                --enable-checking=release \
                --enable-clocale=gnu \
                --enable-cloog-backend=isl \
                --enable-gnu-unique-object \
                --with-avrlibc=yes \
                --with-dwarf2 \
                --enable-languages=c,c++ \
                --disable-libada \
                --disable-doc \
                --enable-lto \
                --enable-gold \
                --disable-plugin \
                --prefix=$pkgdir \
                --disable-shared \
                --with-gnu-ld \
                --host=$HOST \
                --build=${config_guess} \
                --target=avr

#remove __HAVE_MALLOC_H__ if cross compiling for OSX
#http://glaros.dtc.umn.edu/gkhome/node/694

make -j8

make -j1 install-strip

find $pkgdir/lib -type f -name "*.a" -exec ${pkgdir_build}/bin/avr-strip --strip-debug '{}' \;

rm -rf $pkgdir/share/man/man7
rm -rf $pkgdir/share/info

cd $home

rm -rf avr-libc

git clone https://github.com/vancegroup-mirrors/avr-libc.git

cd avr-libc/avr-libc

./bootstrap --prefix=$pkgdir/

CC=${pkgdir_build}/bin/avr-gcc ./configure --prefix=$pkgdir/ --build=`./config.guess` --host=avr

make -j8
make install
