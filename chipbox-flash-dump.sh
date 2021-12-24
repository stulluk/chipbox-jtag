#!/bin/bash

# Reads all chipbox CFI Parallel NOR flash part by part

#step1
#JFlash -openprj"chipbox-jflash-project-21.12.2021.jflash" -open"MX29GL256EH.bin" -jflashlog"step$i.log" -readrange"0x38000000","0x381FFFFF" -exit

rm dump/*

cp jflash-chipbox-project.21.12.2021.jflash dump/

cd dump

for startblock in 38 39
do
	for((i=0;i<15;i++))
	do
		curstarthandle=$(printf '%x' $i)
		curendhandle=$(printf '%x' $((i+1)))
		curstartaddr="0x${startblock}${curstarthandle}00000"
		curendaddr="0x${startblock}${curendhandle}fffff"
		printf "curstarthandle: ${curstarthandle} \t  curendhandle: ${curendhandle} \t curstartaddr: ${curstartaddr} \t curendaddr: ${curendaddr} \n"
		touch "${curstartaddr}-${curendaddr}.bin"
		JFlash -openprj"jflash-chipbox-project.21.12.2021.jflash" -readrange"${curstartaddr}","${curendaddr}" -saveas"${curstartaddr}-${curendaddr}.bin" -save -exit &
		sleep 20
		xdotool key Return
		cat "${curstartaddr}-${curendaddr}.bin" >> All32M.bin
		i=$((i+1))
		ls -lah *.bin
	done
done

cd ..

exit 

for startblock in 38 39
do
	for((i=0;i<15;i++))
	do
		curstarthandle=$(printf '%x' $i)
		curendhandle=$(printf '%x' $((i+1)))
		curstartaddr="0x${startblock}${curstarthandle}00000"
		curendaddr="0x${startblock}${curendhandle}fffff"
		printf "curstarthandle: ${curstarthandle} \t  curendhandle: ${curendhandle} \t curstartaddr: ${curstartaddr} \t curendaddr: ${curendaddr} \n"
		JFlash -openprj"chipbox-jflash-project-21.12.2021.jflash" -open"${curstartaddr}-${curendaddr}.bin" -jflashlog"log-${curstartaddr}-${curendaddr}.log" -readrange"${curstartaddr}","${curendaddr}" -exit
	done
done
