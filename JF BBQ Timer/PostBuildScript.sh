#!/bin/bash
set -e

echo "Starting sound resources copy process..."

# Create Resources directory in the app bundle if it doesn't exist
SOUNDS_DIR="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/Resources/Sounds"
mkdir -p "${SOUNDS_DIR}"
echo "Created directory: ${SOUNDS_DIR}"

# Source directory for sound files
SOURCE_DIR="${SRCROOT}/JF BBQ Timer/Resources/Sounds"
echo "Copying sounds from: ${SOURCE_DIR}"

# Check if source directory exists
if [ ! -d "${SOURCE_DIR}" ]; then
    echo "Error: Source directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

# Copy all sound files
echo "Copying MP3 files..."
find "${SOURCE_DIR}" -name "*.mp3" -exec cp {} "${SOUNDS_DIR}/" \;

# Copy metadata file
echo "Copying metadata file..."
if [ -f "${SOURCE_DIR}/sound_metadata.json" ]; then
    cp "${SOURCE_DIR}/sound_metadata.json" "${SOUNDS_DIR}/"
    echo "Metadata file copied successfully"
else
    echo "Warning: Metadata file not found: ${SOURCE_DIR}/sound_metadata.json"
fi

# Make the files executable/readable
chmod -R 755 "${SOUNDS_DIR}"

echo "Sound resources copied successfully!" 