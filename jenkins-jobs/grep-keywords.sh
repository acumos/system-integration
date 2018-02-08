#!/bin/bash
# Searches for prohibited strings like att.com.
#
# Requires environment variable BASE_CHECKOUT
# which must be a valid argument for git checkout
#
# Depends on features of Gnu grep as available on Linux;
# does not work with BSD grep as available on Macos.

# be verbose
set -x

IFS=$'\n'

ATTUIDS_F="attuids"
ATT_F="att"
COMATT_F="comatt"
ATTCOM_F="attcom"
ATNT_F="atandt"
TECHM_F="tech_mahindra"
TECHMCOM_F="techmahindra.com"
COMTECHM_F="com.techmahindra"
COGNITA_F="cognita"
FILES_ARRAY=( "$ATTUIDS_F" "$ATT_F" "$COMATT_F" "$ATTCOM_F" "$ATNT_F" "$TECHM_F" "$TECHMCOM_F" "$COMTECHM_F" "$COGNITA_F" )

EXTENSIONS_EXCLUDED="*.png,*.gif,*.jpg,*.jpeg,*.svg,*.bmp"

# limit amount of context shown
CONTEXT=".{0,40"

EXCLUDE_F="{grep-keywords\.sh"
for FILE in "${FILES_ARRAY[@]}"
do
    EXCLUDE_F="$EXCLUDE_F,$FILE\.txt"
done
EXCLUDE_F="$EXCLUDE_F,$EXTENSIONS_EXCLUDED}"

EXCLUDE_DIR="\.git"
GREP_EXCLUDE="--exclude=$EXCLUDE_F --exclude-dir=\"$EXCLUDE_DIR\""
# Reduce the number of false positives
ATT_PATTERNS_EXCLUDED=( "pattern" "attrib" "attach" "[hH]eat[tT]" "[Ff]ormatt" "attempt" "[Ff]loatT" "[Mm]atter" "[Ll]atter" )
OTHER_PATTERNS_EXCLUDED=( "distributed by AT&T and Tech Mahindra" "Copyright (C) 2017 AT&T Intellectual" )

REPO="./"
PUBLISH_DIR="publish"
NEW_DIR="$PUBLISH_DIR/$BUILD_TAG/new"
OLD_DIR="$PUBLISH_DIR/$BUILD_TAG/old"
DIFF_DIR="$PUBLISH_DIR/$BUILD_TAG/diff"
VERSION_FILE="version.txt"

HEADER="This file was generated with"
LINE="===================================="

function scan {
    GREP=$1
    FILE=$2
    OUTPUT=$3
    echo "PROCESSING $GREP OUTPUT TO DIR $OUTPUT FILE $FILE"
    echo "$HEADER $GREP"        >  "$OUTPUT/$FILE.txt"
    echo "$LINE"                >> "$OUTPUT/$FILE.txt"
    eval "$GREP" "$REPO" | sort >> "$OUTPUT/$FILE.txt"
}

function scanAll {
    OUTPUT=$1
    echo "SCANNING FOR $OUTPUT"
    scan "grep -rHoE \"$CONTEXT}[a-zA-Z][a-zA-Z][0-9][0-9][0-9][0-9a-zA-Z]$CONTEXT}\" $GREP_EXCLUDE"  "$ATTUIDS_F"    "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}att$CONTEXT}\" $GREP_EXCLUDE"                                        "$ATT_F"        "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}com\.att$CONTEXT}\" $GREP_EXCLUDE"                                   "$COMATT_F"     "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}att\.com$CONTEXT}\" $GREP_EXCLUDE"                                   "$ATTCOM_F"     "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}at&t$CONTEXT}\" $GREP_EXCLUDE"                                       "$ATNT_F"       "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}tech mahindra$CONTEXT}\" $GREP_EXCLUDE"                              "$TECHM_F"      "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}com\.techmahindra$CONTEXT}\" $GREP_EXCLUDE"                          "$COMTECHM_F"   "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}techmahindra\.com$CONTEXT}\" $GREP_EXCLUDE"                          "$TECHMCOM_F"   "$OUTPUT"
    scan "grep -riHoE \"$CONTEXT}cognita$CONTEXT}\" $GREP_EXCLUDE"                                    "$COGNITA_F"    "$OUTPUT"
}

function diff {
    FILENAME=$1
    echo "DOING DIFF FOR $1"
    echo "ADDED FROM $BASE_CHECKOUT"                    >   "$DIFF_DIR/$FILENAME"
    echo "$LINE"                                        >>  "$DIFF_DIR/$FILENAME"
    grep -vFf "$OLD_DIR/$FILENAME" "$NEW_DIR/$FILENAME" >>  "$DIFF_DIR/$FILENAME"
}

function excludeAttPatterns {
    DIR=$1
    for EXCLUSION in "${ATT_PATTERNS_EXCLUDED[@]}"
    do
        echo "EXCLUDING $EXCLUSION FROM $DIR/$ATT_F.txt"
        sed -i "s/$EXCLUSION//gI" "$DIR/$ATT_F.txt"
        sed -i "/[aA][tT][tT]/!d" "$DIR/$ATT_F.txt"
    done
}

function excludeOtherPatterns {
    DIR=$1
    for FILE in "${FILES_ARRAY[@]}"
    do
        for EXCLUSION in "${OTHER_PATTERNS_EXCLUDED[@]}"
        do
            echo "EXCLUDING $EXCLUSION FROM ${DIR}/${FILE}.txt"
            sed -i "s/$EXCLUSION//gI" "$DIR/${FILE}.txt"
        done
    done
}

echo "Creating folders"
mkdir -p "$NEW_DIR"
mkdir -p "$OLD_DIR"
mkdir -p "$DIFF_DIR"

echo "Scanning new version :"
git log -1
scanAll "$NEW_DIR"
excludeAttPatterns "$NEW_DIR"
excludeOtherPatterns "$NEW_DIR"
git log -1 > "$NEW_DIR/$VERSION_FILE"

git checkout "$BASE_CHECKOUT"

echo "Scanning old version $BASE_CHECKOUT :"
git log -1
scanAll "$OLD_DIR"
excludeAttPatterns "$OLD_DIR"
excludeOtherPatterns "$OLD_DIR"
git log -1 > "$OLD_DIR/$VERSION_FILE"

echo "producing the diff"
for FILE in "${FILES_ARRAY[@]}"
do
    diff "$FILE.txt"
done
