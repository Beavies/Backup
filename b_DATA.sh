#!/bin/bash
#######################################################
# Backup de Base de datos de Navision i PC ACCESO
#######################################################
# requiere entrada en fstab para montar la unidad
#//192.168.131.76/BACK   /home/user/navdir   cifs  user,noauto,ro,credentials=/home/user/navcred.txt   0 0

DIA=$(date --date='1 day ago' +%Y_%m_%d)
NAVDIR="/home/user/navdir"
NASDIR="/home/user/NAS"
ACCESODIR="/home/user/acceso"
NAVBACKUPFILE="LK_Produccion_backup_""$DIA"
BAK_NAVISION=1
BAK_HUELLAS=1

#
# 1. copia, comprimie y cifra de Server navision -> NAS, elimina copias con + de 5 días de antiguedad del NAS
# 2. copia y comprime del Server Navision -> Google Drive
#
do_backup_navision() {

	# para descifrar: dd if="fichero.enc" | openssl enc -aes-256-cbc -d -salt -pbkdf2 -k PASSWORD | tar xzf -
	find $NASDIR/Navision -name "*_LK_*" -mtime +5 -exec rm -f {} \;
	echo "Limpieza backups anteriores de Navision en NAS............ok"
	tar -czf - "${NAVDIR}/$NAVBACKUPFILE"* | openssl enc -aes-256-cbc -pbkdf2 -salt -k PASSWORD | dd of=${NASDIR}/Navision/${DIA}_LK_produccion.tar.gz.enc

	if [ $(stat -c%s ${NASDIR}/Navision/${DIA}_LK_produccion.tar.gz.enc) -gt 200 ]; then
		echo "Copia ${DIA}_LK_produccion realizada......................ok"
		
		##
		#2o copia a google drive
		##
		tar -zcf - "${NAVDIR}/${NAVBACKUPFILE}"* | rclone rcat BACKUP_DATA:/Navision/${DIA}_LK_produccion.tar.gz
		if [ $? -eq 0 ]; then
			echo "Copia ${DIA}_LK_produccion.tar.gz subida al Drive.........ok"
		else
			echo "Copia ${DIA}_LK_produccion.tar.gz subida al Drive.........ERROR"
		fi

	else
		echo "Copia ${DIA}_LK_produccion realizada......................ERROR"
	fi

}

#
# 1. copiar y comprimir BBDD huellas de PCACCESO -> NAS
# 2. Copiar y comprimir BBDD Huelas de PCACCESO -> google drive
#
do_backup_huellas() {

	find $NASDIR/Huellas -name "*_advsoft_sql.bak" -mtime +10 -exec rm -f {} \;
	echo "Limpieza backups anteriores de Huellas en NAS.............ok"

	tar -czf "$NASDIR/Huellas/${DIA}_advsoft_sql.tar.gz" "$ACCESODIR/advsoft_sql.bak"
	
	if [ $? -eq 0 ]; then
		echo "Copia ${DIA}_advsoft_sql.bak..............................ok"
	
		tar -czf - "$ACCESODIR/advsoft_sql.bak" | rclone rcat BACKUP_DATA:/Huellas/${DIA}_advsoft_sql.tar.gz
		
		if [ $? -eq 0 ]; then
        	        echo "Copia ${DIA}_advsoft_sql.tar.gz subida al Drive.........ok"
	        else
        	        echo "Copia ${DIA}_advsoft_sql.tar.gz subida al Drive.........ERROR"
	        fi
	else
		echo "Copia ${DIA}_advsoft_sql.bak..............................ERROR"
	fi
}

##################
# MONTAR UNIDADES
##################
mount | grep $NAVDIR > /dev/null
if [ $? -eq 0 ]; then
	umount $NAVDIR
fi
mount $NAVDIR

mount | grep $NASDIR > /dev/null
if [ $? -eq 0 ]; then
	umount $NASDIR
fi
mount $NASDIR

mount | grep $ACCESODIR > /dev/null
if [ $? -eq 0 ]; then
	umount $ACCESODIR
fi
mount $ACCESODIR

###################
# VERIFICACION
###################
m1=$(mount | grep $NAVDIR)
m2=$(mount | grep $NASDIR)
m3=$(mount | grep $ACCESODIR)

#debug
#echo $m1 
#echo
#echo $m2 
#echo
#echo $m3

if [[ -z $m1 || -z $m2 ]]; then
	echo "ERROR: No se ha podido montar unidad de Navision o Backup del NAS"
	echo "Saltando backup de Navision..."
	BAK_NAVISION=0
fi

if [[ -z $m2 || -z $m3 ]]; then
	echo 
	echo "ERROR: No se ha podido montar unidad de PC-ACCESO o NAS"
	echo "Saltando backup de Huellas..."
	BAK_HUELLAS=0
fi

####################
# Forzado Acciones
####################

if [[ $1 == "HUELLAS" ]]; then
	BAK_NAVISION=0
fi

if [[ $1 == "NAVISION" ]]; then
	BAK_HUELLAS=0
fi

#debug
#echo $BAK_NAVISION - $BAK_HUELLAS

###########
# BACKUPS
###########

if [[ $BAK_NAVISION -eq 1 ]]; then
	echo "Conexión con Navision.....................................ok"
	echo "Conexión con NAS..........................................ok"
	do_backup_navision
fi

if [[ $BAK_HUELLAS -eq 1 ]]; then
	echo 
	echo "Conexión con PC-ACCES.....................................ok"
	echo "Conexión con NAS..........................................ok"
	do_backup_huellas
fi

############
# DESMONTAR
############
umount $NAVDIR
umount $NASDIR
umount $ACCESODIR


