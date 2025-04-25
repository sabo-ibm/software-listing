#!/bin/bash
# AIX script para listar swg instalado en un servidor
# Basado en lslpp -lc -a -q queries Description 
# Compatible con AIX on Power
# Resultados y system specs guardados a disco
# April 2025 


# software match vs description
SOFTWARE_LIST=("ibm" "IBM" "db2" "DB2" "mq" "MQ" "api" "API" "Connect" "CONNECT" "Sterling" "STERLING")

# Server name
serverName=$(hostname)
serverName=$(echo "$serverName" | tr '/:.*' '_')

# Output files with server name
SOFTWARE_OUTPUT_FILE="software_inventory_$serverName.txt"  # Software inventory
SPECS_OUTPUT_FILE="system_specs_$serverName.txt"          # System specifications


# temporary file software 
TEMP_DIR="./"
# Use process ID and timestamp for uniqueness
TEMP_FILE="${TEMP_DIR}/software_list_$$_$(date +%s).tmp"

# temporary file created
if [ -f "$TEMP_FILE" ]; then
    echo "Error: Temporal file $TEMP_FILE ya existe. Eliminar para continuar"
    exit 1
fi
touch "$TEMP_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Imposible crear temp file $TEMP_FILE"
    exit 1
fi

# Remove temp on exit
trap "rm -f $TEMP_FILE" EXIT

# Match vs pattern SOFTWARE_LIST
matches_list() {
    local name="$1"
    echo "Procesando: " "${name,,}"
    for pattern in "${SOFTWARE_LIST[@]}"; do
        if echo "${name,,}" | grep -qi "${pattern,,}"; then
            echo "se encontro:" ${pattern}
            return 0
        fi
    done
    return 1
}

# Check lslpp 
if ! command -v lslpp >/dev/null 2>&1; then
    echo "Error: lslpp command not found. Is this an AIX system?"
    rm -f "$TEMP_FILE"
    exit 1
fi

# filesets con lslpp command
lslpp -lc -a -q | awk -F: '{print $2 ":" $3 ":" $7}' > "$TEMP_FILE" 2>/dev/null

# lslpp command 
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve software list with lslpp"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Initialize software output file
echo "Software instalado cumpliendo patrones :" > "$SOFTWARE_OUTPUT_FILE"
echo "----------------------------------------" >> "$SOFTWARE_OUTPUT_FILE"
echo "Fileset:Level:Descricion" >> "$SOFTWARE_OUTPUT_FILE"


while read -r line; do
     if matches_list "$line"; then
         echo "$line" >> "$SOFTWARE_OUTPUT_FILE"
     fi
done < "$TEMP_FILE"

# Count matches
match_count=$(($(wc -l < "$SOFTWARE_OUTPUT_FILE") - 3))

echo "Se encontraron $match_count matchs"
echo "Bajando inventario a: $SOFTWARE_OUTPUT_FILE"

# Collect and save machine specifications
echo "System Specs ..."

# Initialize specs output file
echo "System Specs" > "$SPECS_OUTPUT_FILE"
echo "--------------------" >> "$SPECS_OUTPUT_FILE"
echo "Generado: $(date)" >> "$SPECS_OUTPUT_FILE"
echo "" >> "$SPECS_OUTPUT_FILE"

# Get system details using prtconf
if command -v prtconf >/dev/null 2>&1; then
    {
        echo "System Model:"
        prtconf | grep "System Model" | awk -F: '{print $2}' | sed 's/^[ \t]*//'
        echo ""

        echo "Machine Serial Number:"
        prtconf | grep "Machine Serial Number" | awk -F: '{print $2}' | sed 's/^[ \t]*//'
        echo ""

        echo "Processor Type:"
        prtconf | grep "Processor Type" | awk -F: '{print $2}' | sed 's/^[ \t]*//'
        echo ""

        echo "Number of Processors:"
        prtconf | grep "Number Of Processors" | awk -F: '{print $2}' | sed 's/^[ \t]*//'
        echo ""

        echo "Processor Clock Speed:"
        prtconf | grep "Processor Clock Speed" | awk -F: '{print $2}' | sed 's/^[ \t]*//'
        echo ""

        echo "Memory Size:"
        prtconf | grep "Memory Size" | awk -F: '{print $2}' | sed 's/^[ \t]*//'
        echo ""

        echo "Kernel Type:"
        prtconf | grep "Kernel Type" | awk -F: '{print $2}' | sed 's/^[ \t]*//'
        echo ""

        echo "Operating System Version:"
        oslevel -r | awk '{print $1}' && oslevel -s | awk '{print "Service Pack: " $1}'
    } >> "$SPECS_OUTPUT_FILE" 2>/dev/null
else
    echo "Error: prtconf no existe. System specs collected." >> "$SPECS_OUTPUT_FILE"
    {
        echo "Operating System Version:"
        oslevel -r | awk '{print $1}' && oslevel -s | awk '{print "Service Pack: " $1}'
    } >> "$SPECS_OUTPUT_FILE"
fi

# Check if specs were collected successfully
if [ -s "$SPECS_OUTPUT_FILE" ]; then
    echo "System specifications bajados a: $SPECS_OUTPUT_FILE"
else
    echo "Error: Falla recolectando system specs"
fi