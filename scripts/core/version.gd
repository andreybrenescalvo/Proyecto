class_name Version
extends RefCounted
## Qué versión del juego es esta (se muestra en el menú y en el título de la ventana).
##
## El texto entre $Format:...$ lo reemplaza Git solo, cuando GitHub arma el ZIP de descarga
## (ver .gitattributes: export-subst). Así cada descarga dice de qué commit y de qué día es.
## En una copia de trabajo de Git sin descargar como ZIP queda sin reemplazar: se muestra "desarrollo".

const RAW := "$Format:%h · %cs$"

static func text() -> String:
	if RAW.begins_with("$Format"):
		return "desarrollo"
	return RAW
