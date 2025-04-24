#!/bin/bash
# Linux script to find installed software matching specific criteria

# Option 1: Search for a specific string
#SEARCH_STRING="yoursoftware"  # Replace with your software name/pattern (case-insensitive)

# Option 2: Array of software names to match against
SOFTWARE_LIST=("IBM" "mettle" "ibm", "api", "app", "db2", "cognos")

# Output file
OUTPUT_FILE="/tmp/software_inventory.txt"  # Adjust path as needed

# Create temporary file
TEMP_FILE=$(mktemp)

# Function to check if a string matches any pattern in SOFTWARE_LIST
matches_list() {
    local name="$1"
    for pattern in "${SOFTWARE_LIST[@]}"; do
        if [[ "${name,,}" =~ ${pattern,,} ]]; then
            return 0
        fi
    done
    return 1
}

# Detect package manager and list installed packages
if command -v dpkg >/dev/null 2>&1; then
    # Debian/Ubuntu systems
    dpkg -l | awk '/^ii/ {print $2 " " $3}' > "$TEMP_FILE"
elif command -v rpm >/dev/null 2>&1; then
    # Red Hat/CentOS systems
    rpm -qa --qf '%{NAME} %{VERSION}\n' > "$TEMP_FILE"
elif command -v pacman >/dev/null 2>&1; then
    # Arch Linux
    pacman -Q | awk '{print $1 " " $2}' > "$TEMP_FILE"
else
    echo "No supported package manager found"
    exit 1
fi