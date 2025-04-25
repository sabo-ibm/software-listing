#!/bin/bash
# Linux script para listar swg instalado en un servidor
# Resultados y system specs guardados a disco
# April 2025 

SOFTWARE_LIST=("yoursoftware1" "yoursoftware2" "yoursoftware3")

# Salidas a disco a current dir
SOFTWARE_OUTPUT_FILE="software_inventory.txt"  # Software inventory
SPECS_OUTPUT_FILE="system_specs.txt"          # System specifications

# Temp files
TEMP_DIR="/tmp"
TEMP_FILE="${TEMP_DIR}/software_list_$$_$(date +%s).tmp"

echo "Temp file..."
if [ -f "$TEMP_FILE" ]; then
    echo "Error: Temporal file $TEMP_FILE existente. Eliminar para continuar"
    exit 1
fi
touch "$TEMP_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Imposible crear temp file $TEMP_FILE"
    exit 1
fi

# Temporary file removed on exit
trap "rm -f $TEMP_FILE" EXIT

# Check string matching vs SOFTWARE_LIST
matches_list() {
    local name="$1"
    for pattern in "${SOFTWARE_LIST[@]}"; do
        if echo "${name,,}" | grep -qi "${pattern,,}"; then
            return 0
        fi
    done
    return 1
}

# Package manager del servidor
echo "Detectando package manager..."
PACKAGE_MANAGER=""
if command -v dpkg >/dev/null 2>&1; then
    PACKAGE_MANAGER="dpkg"
elif command -v rpm >/dev/null 2>&1; then
    PACKAGE_MANAGER="rpm"
elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
elif command -v zypper >/dev/null 2>&1; then
    PACKAGE_MANAGER="zypper"
elif command -v pacman >/dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
elif command -v apk >/dev/null 2>&1; then
    PACKAGE_MANAGER="apk"
else
    echo "Error: No se encontrol un Package manager soportado (dpkg, rpm, dnf, zypper, pacman, apk)"
    rm -f "$TEMP_FILE"
    exit 1
fi
echo "Detectado package manager: $PACKAGE_MANAGER"

# Step 3: Listing installed packages
echo "Listando packages..."
case $PACKAGE_MANAGER in
    dpkg)
        dpkg -l | awk '/^ii/ {print $2 ":" $3}' > "$TEMP_FILE" 2>/dev/null
        ;;
    rpm)
        rpm -qa --qf '%{NAME}:%{VERSION}\n' > "$TEMP_FILE" 2>/dev/null
        ;;
    dnf)
        dnf list installed | awk 'NR>1 {print $1 ":" $2}' > "$TEMP_FILE" 2>/dev/null
        ;;
    zypper)
        zypper se -i | awk '/^i / {print $3 ":" $5}' > "$TEMP_FILE" 2>/dev/null
        ;;
    pacman)
        pacman -Q | awk '{print $1 ":" $2}' > "$TEMP_FILE" 2>/dev/null
        ;;
    apk)
        apk info -v | awk '{print $1 ":" $1}' > "$TEMP_FILE" 2>/dev/null
        ;;
esac

# Check package list
if [ $? -ne 0 ] || [ ! -s "$TEMP_FILE" ]; then
    echo "Error: Imposible obtener package list o no hay packages"
    rm -f "$TEMP_FILE"
    exit 1
fi
echo "Packages listos. Bajando a temp file."

# Step 4: Filtering packages
# Initialize output file
echo "Matching criteria:" > "$SOFTWARE_OUTPUT_FILE"
echo "----------------------------------------" >> "$SOFTWARE_OUTPUT_FILE"
echo "Package:Version" >> "$SOFTWARE_OUTPUT_FILE"

# Filtrado por lista de software 
 while read -r line; do
     if matches_list "$line"; then
         echo "$line" >> "$SOFTWARE_OUTPUT_FILE"
     fi
done < "$TEMP_FILE"

# Check filtrado
if [ $(wc -l < "$SOFTWARE_OUTPUT_FILE") -le 3 ]; then
    echo "Warning: No packages matched "
else
    echo "Packages bajados a: $SOFTWARE_OUTPUT_FILE"
fi

# Count matches (excluding header lines)
match_count=$(($(wc -l < "$SOFTWARE_OUTPUT_FILE") - 3))
echo "Se encontraron $match_count packages"

# Step 5: System Specs
echo "System specs..."

# output file
echo "System Specs" > "$SPECS_OUTPUT_FILE"
echo "--------------------" >> "$SPECS_OUTPUT_FILE"
echo "Generado: $(date)" >> "$SPECS_OUTPUT_FILE"
echo "" >> "$SPECS_OUTPUT_FILE"

# Collect system details
{
    echo "System Model:"
    if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
        cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "Not available"
    else
        echo "Not available"
    fi
    echo ""

    echo "Hostname:"
    hostname 2>/dev/null || echo "Not available"
    echo ""

    echo "Processor Type:"
    lscpu | grep "Model name" | awk -F: '{print $2}' | sed 's/^[ \t]*//' 2>/dev/null || echo "Not available"
    echo ""

    echo "Number of CPUs:"
    lscpu | grep "^CPU(s):" | awk '{print $2}' 2>/dev/null || echo "Not available"
    echo ""

    echo "CPU Architecture:"
    lscpu | grep "Architecture" | awk -F: '{print $2}' | sed 's/^[ \t]*//' 2>/dev/null || echo "Not available"
    echo ""

    echo "Total Memory:"
    free -h | grep "Mem:" | awk '{print $2}' 2>/dev/null || echo "Not available"
    echo ""

    echo "Operating System:"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    else
        uname -s -r
    fi
    echo ""

    echo "Kernel Version:"
    uname -r 2>/dev/null || echo "Not available"
} >> "$SPECS_OUTPUT_FILE" 2>/dev/null

# Check if specs were collected successfully
if [ -s "$SPECS_OUTPUT_FILE" ]; then
    echo "System specs bajados a: $SPECS_OUTPUT_FILE"
else
    echo "Error: on System Specs"
fi

echo "Done!"
