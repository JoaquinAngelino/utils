#!/bin/bash

# Paso 1: Ir a la carpeta "android" si no estamos en ella
if [[ "$(basename "$PWD")" != "android" ]]; then
    if [[ -d "android" ]]; then
        cd android || { echo "No pude moverme a la carpeta android."; exit 1; }
    else
        echo "No existe la carpeta android en este directorio."
        exit 1
    fi
fi

# Nombre del proyecto (carpeta superior a android) y nombre destino del apk
parent_dir_name=$(basename "$(dirname "$PWD")")
cod_cliente=$(echo "$parent_dir_name" | sed 's/-app$//' | tr '[:lower:]' '[:upper:]')

# Fecha actual (YYYYMMDD)
fecha_actual=$(date +"%Y%m%d")

build_gradle_path="app/build.gradle"
if [[ ! -f "$build_gradle_path" ]]; then
    echo "No se encuentra $build_gradle_path"
    exit 1
fi

version_code=$(awk '/versionCode/ {for(i=1;i<=NF;i++){if($i ~ /^[0-9]+$/){print $i; exit}}}' "$build_gradle_path")
if [[ -z "$version_code" ]]; then
    echo "No se pudo obtener el versionCode del build.gradle"
    exit 1
fi

version_name=$(awk -F '"' '/versionName/ {print $2; exit}' "$build_gradle_path")
if [[ -z "$version_name" ]]; then
    echo "No se pudo obtener el versionName del build.gradle"
    exit 1
fi

# Obtener applicationId desde build.gradle
application_id=$(awk -F '"' '/applicationId/ {print $2; exit}' "$build_gradle_path")
if [[ -z "$application_id" ]]; then
    echo "No se pudo obtener el applicationId del build.gradle"
    exit 1
fi

# Construir nombre destino del apk
apk_dest_name="${fecha_actual}_${cod_cliente}_v${version_name}_${version_code}.apk"

# Compilar APK release
if ./gradlew assembleRelease; then
    apk_path="app/build/outputs/apk/release/app-release.apk"
    if [[ -f "$apk_path" ]]; then
        mv "$apk_path" ~/Android/Sdk/"$apk_dest_name" || { echo "No se pudo mover el APK a ~/Android/Sdk/"; exit 1; }
        echo "APK movido a ~/Android/Sdk/$apk_dest_name"
    else
        echo "No se encontró el archivo $apk_path"
        exit 1
    fi

    # Instalar APK en el dispositivo/emulador
    echo "El applicationId detectado es: $application_id"
    cd ~/Android/Sdk/ || { echo "No se pudo acceder a ~/Android/Sdk/"; exit 1; }
    if adb shell pm list packages | grep -q "$application_id"; then
        echo "La app ya está instalada. Desinstalando $application_id..."
        adb uninstall "$application_id"
    fi
    echo "Instalando $apk_dest_name..."
    adb install "$apk_dest_name"

    xdg-open "https://drive.google.com/drive/u/1/folders/1NLHMJdUNY28RNL4fRtyJs9KGe8iaxH6f"
else
    echo "La compilación falló."
    exit 1
fi
