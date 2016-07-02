#!/bin/sh                                                                       

# Build bootloader                                                              
nasm -f bin ./asm/bootsec.asm -o ./build/bootsec.bin

# Build game core                                                          
# gcc src/tetris.c -nostdlib -std=c99 -O3 -o kernel -Wall -o build/core.bin -ffreestanding
# objcopy -O binary build/core.bin build/core.bin

# Concat all files into one
cat ./build/bootsec.bin > ./build/tetris.img
xxd -p build/tetris.img

# Remove old files
rm ./build/bootsec.img
# rm ./build/core.img

# Run emulator                                                                  
bochs
