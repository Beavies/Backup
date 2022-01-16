#!/bin/bash
#########################################
# Script de backups
#########################################

########################
# COLORS
########################
green="\e[42m"
blue="\e[1;34m"
red="\e[31m"
bold="\e[1m"
end="\e[0m"

########################
# Google Drive
########################

GD_Control_Versiones() {
	local remote="$1"
	local num_versions=30
	local versions=( $(rclone lsd $remote | cut -d '-' -f 5 | cut -d ' ' -f 2 | grep -e '^20' | sort -r | xargs) )
	local versions_to_remove=( ${versions[@]:$num_versions:100} )

	echo -e "\t[+] Control de versiones de $remote"
	echo -e "\t\tVersiones encontradas: ${versions[@]}"
	echo -e "\t\tVersiones a eliminar: ${versions_to_remove[@]}"

	for v in ${versions_to_remove[@]}; do
		echo -e "\t\tEliminando $v"
		rclone purge $remote/$v
	done
}

GD_Control_Cambios() {
	local ORIG="$1"
	local DEST="$2"
	local NUMFILES=$(rclone size $ORIG)
	local NUMCHANGED=$(rclone size $DEST) 

	echo 
	echo -e "\t[+] Control de cambios de $DEST"

	if [[ -z $NUMFILES || -z $NUMCHANGED ]]; then
        	echo -e "\t\t$DEST no existe - no cambios - ok"
	else
		NUMFILES=$(echo $NUMFILES     | grep object | cut -d ':' -f 2 | cut -d ' ' -f 2 | xargs)
		NUMCHANGED=$(echo $NUMCHANGED | grep object | cut -d ':' -f 2 | cut -d ' ' -f 2 | xargs)
		
		echo -e "\t\tNumero de archivos en $ORIG: $NUMFILES"
		echo -e "\t\tNumero de archivos cambiados en $DEST: $NUMCHANGED"

		RELATION=$((NUMCHANGED*100/NUMFILES))
		if [[ $RELATION -ge 10 ]]; then
			echo -e "\t\tOJO!!, se ha detectado un porcentaje elevado de cambios en $DEST: $RELATION %"
			echo "MUCHOS CAMBIOS EN BACKUP DE $ORIG: $RELATION %" | swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIG WARNING"
		fi
	fi
}

Help() {
	# mostrar la ayuda
	echo "Script para sincronizar incrementalmente carpetas de google drive"
	echo "configuradas en rclone."
	echo 
	echo "Parametros requeridos:"
	echo -e "-h \t Ayuda"
	echo -e "-o \t Origen (remote de rclone)"
	echo -e "-d \t Destino (remote de rclone)"
	echo -e "-r \t Listar unidades remotas de rclone"
	echo
}

#fecha actual para mantener la versiona anterior de los ficheros modificados hoy
fecha_actual=$(date +%Y%m%d)

# Recogida de parametros
while getopts "hro:d:" option; do
	case $option in
		h) Help ; exit 0 ;;
		r) echo "Listando unidades remotas:"; echo; rclone listremotes; exit 0;;
		o) ORIGEN=$OPTARG ;;
		d) DESTINO=$OPTARG ;;
		\?) exit 1 ;;
		:)  exit 1 ;;
	esac
done

if [ -z $ORIGEN ] || [ -z $DESTINO ]; then
	echo -e "${bold}${red}ERROR: no se ha definido el origen o destino.${end}"
	echo 
	Help
	exit 1
fi

# Copia de origen a destino y control de versiones (borrado de modificaciones viejas)
TMP=$(mktemp)
echo -e "[+] $fecha_actual [+] Copiando Google Drive: $ORIGEN a $DESTINO"

rclone --drive-server-side-across-configs --drive-stop-on-upload-limit sync $ORIGEN $DESTINO/current --backup-dir $DESTINO/$fecha_actual --log-file $TMP
EXIT_CODE=$?

cat $TMP | paste /dev/null - && rm -f $TMP
GD_Control_Versiones $DESTINO
GD_Control_Cambios "$ORIGEN" "$DESTINO/$fecha_actual"

case $EXIT_CODE in
	0) : ;; #success
	1) echo "Rclone con errores revisar log"		| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	2) echo "Rclone error raro" 				| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	3) echo "Directory not found" 				| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	4) echo "File not found" 				| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	5) echo "temporary error -> more retries" 		| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	6) echo "Less serious error" 				| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	7) echo "Fatal Error (Account suspended, limits)" 	| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	8) echo "Transfer exceeded" 				| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
	9) echo "Ok but no files transfered" 			| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORGIEN ERROR" ;;
	*) echo "Rclone return code not documented"		| swaks -n --output /dev/null --h-Subject "[BACKUP] $ORIGEN ERROR" ;;
esac

