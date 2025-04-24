#!/bin/bash
# AIX script to find installed software matching specific criteria in Description
# Uses lslpp -lc -a -q and queries the Description column
# Saves machine specifications to a separate file
# Compatible with AIX on Power

# Array of software names to match against in Description
SOFTWARE_LIST=("ibm" "IBM" "db2")

# Output files
SOFTWARE_OUTPUT_FILE="software_inventory.txt"  # Software inventory
SPECS_OUTPUT_FILE="system_specs.txt"          # Machine specifications

# Create temporary file for software list
TEMP_DIR="/tmp"
# Use process ID and timestamp for uniqueness
TEMP_FILE="${TEMP_DIR}/software_list_$$_$(date +%s).tmp"

# Ensure temporary file is unique and created
if [ -f "$TEMP_FILE" ]; then
    echo "Error: Temporary file $TEMP_FILE already exists. Please try again."
    exit 1
fi
touch "$TEMP_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to create temporary file $TEMP_FILE"
    exit 1
fi

# Ensure temporary file is removed on script exit
trap "rm -f $TEMP_FILE" EXIT

# Function to check if a string matches any pattern in SOFTWARE_LIST
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

# Check if lslpp is available
if ! command -v lslpp >/dev/null 2>&1; then
    echo "Error: lslpp command not found. Is this an AIX system?"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Get installed filesets using specified lslpp command
lslpp -lc -a -q | awk -F: '{print $2 ":" $3 ":" $7}' > "$TEMP_FILE" 2>/dev/null

# Check if lslpp command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve software list with lslpp"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Initialize software output file
echo "Installed software matching criteria:" > "$SOFTWARE_OUTPUT_FILE"
echo "----------------------------------------" >> "$SOFTWARE_OUTPUT_FILE"
echo "Fileset:Level:Description" >> "$SOFTWARE_OUTPUT_FILE"


# Option 2: Filter by list of software names in Description (comment out Option 1 and uncomment this)
 while read -r line; do
     if matches_list "$line"; then
         echo "$line" >> "$SOFTWARE_OUTPUT_FILE"
     fi
 done < "$TEMP_FILE"

# Count matches
match_count=$(($(wc -l < "$SOFTWARE_OUTPUT_FILE") - 3))

echo "Found $match_count matching entries"
echo "Software inventory saved to: $SOFTWARE_OUTPUT_FILE"

# Collect and save machine specifications
echo "Collecting system specifications..."

# Initialize specs output file
echo "System Specifications" > "$SPECS_OUTPUT_FILE"
echo "--------------------" >> "$SPECS_OUTPUT_FILE"
echo "Generated: $(date)" >> "$SPECS_OUTPUT_FILE"
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
    echo "Error: prtconf not found. Limited system specs collected." >> "$SPECS_OUTPUT_FILE"
    {
        echo "Operating System Version:"
        oslevel -r | awk '{print $1}' && oslevel -s | awk '{print "Service Pack: " $1}'
    } >> "$SPECS_OUTPUT_FILE"
fi

# Check if specs were collected successfully
if [ -s "$SPECS_OUTPUT_FILE" ]; then
    echo "System specifications saved to: $SPECS_OUTPUT_FILE"
else
    echo "Error: Failed to collect system specifications"
fi