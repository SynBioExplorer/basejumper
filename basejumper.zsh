#!/bin/zsh
#Enable debug mode
set -ex
## Receive inputs as arguments
BASECALLING_ANSWER=$1
DORADO_INPUT_DIR=$2
DORADO_OUTPUT_DIR=$3
INPUT_DIR=""
OUTPUT_DIR=""
QUAST_ANSWER=$4
REFERENCE_FILE=$5
NUM_BARCODES=$6
OUT_DIR_BASE=$7
KIT_NAME=$8

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Check for dependencies
dependencies=("flye" "quast.py" "NanoPlot")

for dep in "${dependencies[@]}"; do
  if ! command -v $dep &> /dev/null; then
    echo "Error: $dep is not installed or not in the PATH. Please install it or add it to the PATH and try again."
    exit 1
  fi
done

# Check which basecaller is selected
if [[ "$BASECALLING_ANSWER" == "dorado" ]]; then
    # If basecalling with Dorado
    # Assuming Dorado uses the same input and output directory structure
    DORADO_INPUT_DIR=$2
    DORADO_OUTPUT_DIR=$3
    BASE_DIR="${DORADO_OUTPUT_DIR%/}"  # Adjust if Dorado has a different directory structure
else
    # If no basecalling or an invalid option is provided
    INPUT_DIR=$2  # This would be the generic input directory
    OUTPUT_DIR=$3 # This would be the generic output directory
    BASE_DIR="$INPUT_DIR"
fi

# Basecalling and demultiplexing
if [[ "$BASECALLING_ANSWER" == "dorado" ]]; then
    # Dorado basecalling command
    DORADO_BIN_DIR="${SCRIPT_DIR}/dorado/bin/"
    cd "$DORADO_BIN_DIR" || { echo "Failed to change directory to $DORADO_BIN_DIR"; exit 1; }

    # Basecalling step
    if ./dorado basecaller fast "$DORADO_INPUT_DIR" --emit-fastq --no-trim --output-dir "$DORADO_OUTPUT_DIR/basecalled/"; then
        echo "Dorado basecalling successful."

        # Combine all FASTQ files into a single file
        cat "$DORADO_OUTPUT_DIR"/basecalled/*.fastq > "$DORADO_OUTPUT_DIR/basecalled.fastq"
        echo "Combined all basecalled FASTQ files into one."
        # Remove the basecalled folder to save space
        rm -rf "$DORADO_OUTPUT_DIR/basecalled/"
        echo "Removed basecalled folder to save space."
        # Demultiplexing step
        if ./dorado demux --kit-name "$KIT_NAME" --emit-fastq --output-dir "$DORADO_OUTPUT_DIR/demuxed" "$DORADO_OUTPUT_DIR/basecalled.fastq"; then
            echo "Dorado demultiplexing successful."

            # Organize demultiplexed files into barcode-specific directories
            for file in "$DORADO_OUTPUT_DIR/demuxed"/*_barcode*.fastq; do
                barcode=$(echo "$file" | grep -o 'barcode[0-9]\+')
                barcode_dir="$DORADO_OUTPUT_DIR/$barcode/"
                mkdir -p "$barcode_dir"  # Create barcode-specific directory

                # Move the file into the corresponding barcode directory without renaming
                mv "$file" "$barcode_dir/"
            done
            # Remove the demux folder after organizing the files
            rm -rf "$DORADO_OUTPUT_DIR/demuxed/"
            echo "Removed the demuxed folder to save space."
            echo "Files organized into barcode-specific directories."
        else
            echo "Dorado demultiplexing failed."
            exit 1
        fi
    else
        echo "Dorado basecalling failed."
        exit 1
    fi

    # Return to the original directory if needed
    cd -
fi



# Initialize an empty array to hold the paths of the assembly.fasta files
ASSEMBLY_FILES=()
declare -A statsTable

# Set nullglob for this part of the script
setopt local_options nullglob
NANOPLOT_OUT_DIR="${HOME}/run-statistics/" # Change to a writable directory
mkdir -p "${NANOPLOT_OUT_DIR}" 


# Change the NanoPlot output directory to be within the OUTPUT_DIR
if [[ "$BASECALLING_ANSWER" == "dorado" ]]; then
    NANOPLOT_OUT_DIR="${DORADO_OUTPUT_DIR}/run-statistics/" # Use DORADO output directory for nanoplot statistics
else
    NANOPLOT_OUT_DIR="${OUTPUT_DIR}/run-statistics/" # Use the generic output directory for nanoplot statistics
fi


# Loop through each barcode
for (( i=1; i<=${NUM_BARCODES}; i++ )); do
  idx=$(printf "%02d" $i)
  IN_DIR="${BASE_DIR}/barcode${idx}/"
  OUT_DIR="${OUT_DIR_BASE}/assemblies/flye${idx}/"

  mkdir -p "${OUT_DIR}"

  # Check for fastq files and handle if not found
  fastq_files=(${IN_DIR}*.fastq)
  if [ ${#fastq_files[@]} -gt 0 ]; then
    if [ ! -f "${IN_DIR}barcode${idx}.fastq" ]; then
      cat "${fastq_files[@]}" > "${IN_DIR}barcode${idx}.fastq"
    fi
    
    # Run NanoPlot for the concatenated fastq file
    NanoPlot -t 4 --no_static --N50 --fastq "${IN_DIR}barcode${idx}.fastq" -o "${NANOPLOT_OUT_DIR}" -p "barcode${idx}_"

    # Clean up undesired files from NanoPlot output
    for file in "${NANOPLOT_OUT_DIR}barcode${idx}_"*; do
      if [[ $file != *"_NanoPlot-report.html" ]]; then
        rm "$file"
      fi
    done
    
    # Run assembly with Flye
    if flye --nano-hq "${IN_DIR}barcode${idx}.fastq" -o "${OUT_DIR}" --threads 4 --iterations 3; then
      # Check if assembly was successful by checking for the expected output file
      if [[ -f "${OUT_DIR}assembly.fasta" ]]; then
        assemblyInfo=$(awk -F '\t' 'NR == 2 {printf "%s,%s", $2, $3; exit}' "${OUT_DIR}assembly_info.txt")
        statsTable["barcode${idx}"]="barcode${idx},Successful,${assemblyInfo}"
        ASSEMBLY_FILES+=("${OUT_DIR}assembly.fasta") # Add the successful assembly to the list
      else
        statsTable["barcode${idx}"]="barcode${idx},Failed,N/A,N/A"
      fi
    else
      statsTable["barcode${idx}"]="barcode${idx},Failed,N/A,N/A"
    fi
  else
    echo "No fastq files found for barcode${idx}. Skipping."
    statsTable["barcode${idx}"]="barcode${idx},No fastq,N/A,N/A"
  fi
done


# Define QUAST output directory
QUAST_OUT_DIR="${OUT_DIR_BASE}/quast_results/"
mkdir -p "${QUAST_OUT_DIR}"

# Print the value of QUAST_ANSWER to confirm it's set correctly
echo "QUAST_ANSWER is set to '${QUAST_ANSWER}'"

# Confirm the ASSEMBLY_FILES array contents
echo "ASSEMBLY_FILES content before QUAST: ${ASSEMBLY_FILES[*]}"

# Check the length of ASSEMBLY_FILES array
if [[ ${#ASSEMBLY_FILES[@]} -eq 0 ]]; then
    echo "Warning: ASSEMBLY_FILES array is empty. QUAST analysis will not be performed."
else
    echo "ASSEMBLY_FILES array has content. Proceeding with QUAST analysis."
fi


if [[ "$QUAST_ANSWER" == "yes" ]]; then
    quast.py "${ASSEMBLY_FILES[@]}" -r "${REFERENCE_FILE}" -o "${QUAST_OUT_DIR}" --threads 1 --fungus
    echo "QUAST exit status: $?"
else
    echo "QUAST analysis was not requested. Skipping QUAST analysis."
fi

# Define the path for the statistics text file
STATS_FILE="${OUTPUT_DIR}/assembly_statistics.txt"
# Print the header to the statistics file
printf "%-20s %-20s %-20s %-20s\n" "Barcode" "Status" "Total Length" "Mean Coverage" > "$STATS_FILE"
# Print the Flye assembly statistics to the file
for key in "${(@k)statsTable}"; do
  IFS=',' read -rA parts <<< "${statsTable[$key]}"
  printf "%-20s %-20s %-20s %-20s\n" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" >> "$STATS_FILE"
done

# Print the Flye assembly statistics
printf "%-20s %-20s %-20s %-20s %-20s\n"  "Barcode" "Status" "Total Length" "Mean Coverage"
for key in "${(@k)statsTable}"; do
  IFS=',' read -rA parts <<< "${statsTable[$key]}"
  printf "%-20s %-20s %-20s %-20s %-20s\n" "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}"
done