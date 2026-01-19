#!/bin/bash

# Flags
build_bundle=false

usage() {
    echo "Uso: $(basename "$0") [-b]"
    echo "  -b  Genera también el bundle (.aab) con ./gradlew bundleRelease"
}

while getopts ":bh" opt; do
    case "$opt" in
        b)
            build_bundle=true
            ;;
        h)
            usage
            exit 0
            ;;
        ?)
            echo "Opción inválida: -$OPTARG"
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

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

# Construir nombre base para los artefactos
artifact_base_name="${fecha_actual}_${cod_cliente}_v${version_name}_${version_code}"
apk_dest_name="${artifact_base_name}.apk"
bundle_dest_name="${artifact_base_name}.aab"

# Detect OS and find Android SDK directory (macOS and Linux common locations)
if [[ "$(uname)" == "Darwin" ]]; then
    candidates=("$HOME/Library/Android/sdk" "$HOME/Android/Sdk")
    open_cmd="open"
else
    candidates=("$HOME/Android/Sdk" "/opt/android-sdk")
    open_cmd="xdg-open"
fi

sdk_dir=""
for d in "${candidates[@]}"; do
    if [[ -d "$d" ]]; then
        sdk_dir="$d"
        break
    fi
done

if [[ -z "$sdk_dir" ]]; then
    echo "Android SDK directory not found. Tried: ${candidates[*]}"
    echo "If your SDK is in a different path, set ANDROID_SDK_ROOT or create one of the above dirs. Falling back to \$HOME."
    sdk_dir="$HOME"
fi

# Compilar APK release (y bundle si aplica)
gradle_tasks=("assembleRelease")
if $build_bundle; then
    gradle_tasks+=("bundleRelease")
fi

if ! ./gradlew "${gradle_tasks[@]}"; then
    echo "La compilación falló."
    exit 1
fi

apk_path="app/build/outputs/apk/release/app-release.apk"
if [[ -f "$apk_path" ]]; then
    # Ensure destination directory exists
    if [[ ! -d "$sdk_dir" ]]; then
        mkdir -p "$sdk_dir" || { echo "No se pudo crear el directorio $sdk_dir"; exit 1; }
    fi
    mv "$apk_path" "$sdk_dir/$apk_dest_name" || { echo "No se pudo mover el APK a $sdk_dir/"; exit 1; }
    echo "APK movido a $sdk_dir/$apk_dest_name"
else
    echo "No se encontró el archivo $apk_path"
    exit 1
fi

if $build_bundle; then
    if ! ./gradlew bundleRelease; then
        echo "La compilación del bundle falló."
        exit 1
    fi

    bundle_path="app/build/outputs/bundle/release/app-release.aab"
    if [[ -f "$bundle_path" ]]; then
        mv "$bundle_path" "$sdk_dir/$bundle_dest_name" || { echo "No se pudo mover el bundle a $sdk_dir/"; exit 1; }
        echo "Bundle movido a $sdk_dir/$bundle_dest_name"
    else
        echo "No se encontró el archivo $bundle_path"
        exit 1
    fi
fi

# Instalar APK en el dispositivo/emulador
echo "El applicationId detectado es: $application_id"

# Ensure adb is available
if ! command -v adb >/dev/null 2>&1; then
    echo "adb no está disponible en el PATH. Asegúrate de que platform-tools estén instalados y adb sea accesible."
    exit 1
fi

cd "$sdk_dir" || { echo "No se pudo acceder a $sdk_dir"; exit 1; }
if adb shell pm list packages | grep -q "$application_id"; then
    echo "La app ya está instalada. Desinstalando $application_id..."
    adb uninstall "$application_id"
fi
echo "Instalando $apk_dest_name..."
adb install "$apk_dest_name"

# Open the Drive folder using the right command for the platform
if command -v "$open_cmd" >/dev/null 2>&1; then
    "$open_cmd" "https://drive.google.com/drive/u/1/folders/1NLHMJdUNY28RNL4fRtyJs9KGe8iaxH6f"
else
    echo "No se pudo abrir el navegador automáticamente. URL: https://drive.google.com/drive/u/1/folders/1NLHMJdUNY28RNL4fRtyJs9KGe8iaxH6f"
fi
