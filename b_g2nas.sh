#!/bin/bash
##############################################################
# Copia de carpetas compartidas de Google Drive -> NAS/BACKUP
##############################################################
NASDIR="/home/user/NAS"
ROOTDIR="GDrive-Teams"
ROOTBAK="${NASDIR}/${ROOTDIR}"
UNMOUNT=0

Help() {
        # mostrar la ayuda
        echo "Script para sincronizar del Drive al NAS"
        echo 
        echo "Parametros requeridos:"
        echo -e "-h \t Ayuda"
        echo -e "-o \t Origen (remote de rclone)"
        echo -e "-d \t Destino (Carpeta del NAS)"
        echo -e "-r \t Listar unidades remotas de rclone"
        echo
}

########################
# COLORS
########################
green="\e[42m"
blue="\e[1;34m"
red="\e[31m"
bold="\e[1m"
end="\e[0m"

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

###################################
# MONTAR UNIDAD NAS
#################################
mount | grep $NASDIR > /dev/null
if [ $? -ne 0 ]; then
	# Unidad no montada -> montar
        mount $NASDIR
	UNMOUNT=1
else
	#unidad montada -> ¿destino correcto?
	mount | grep $NASDIR | grep 192.168.131.66/backup > /dev/null
	if [ $? -ne 0 ]; then
		echo -e "${bold}${red}ERROR: Unidad NAS montada a otra ubicación.${end}"
		exit 1
	fi
fi

#################################
# COPIA
#################################
TMP=$(mktemp)
rclone --transfers 8 sync "$ORIGEN" "${ROOTBAK}/$DESTINO" --log-file $TMP
cat $TMP | paste /dev/null - && rm -f $TMP

###################################
# DESMONTAR
###################################
if [ $UNMOUNT -eq 1 ]; then
	umount $NASDIR
fi

