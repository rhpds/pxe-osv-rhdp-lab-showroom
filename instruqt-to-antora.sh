#!/bin/bash

# Clone the default repo, if not already there

INSTRUQT_ROOT=/Users/jmaltin/Development/pxe-osv-rhdp-lab/instruqt-source/openshift-lab-preview/
DEST_ROOT=/Users/jmaltin/Development/pxe-osv-rhdp-lab-showroom/

####
# Move around the files, do the asciidoc conversion
####

# Setup directory structure
mkdir -p ${DEST_ROOT}/content/modules/ROOT/{pages,assets/images}
mkdir -p ${DEST_ROOT}/content/libs/

# Assume single module.
# Convert the markdown files from markdown to asciidoc, putting the output in the correct place
# Find all the markdown files, sorted
SOURCE_LIST=$(find -s ${INSTRUQT_ROOT} -name 'assignment.md')
adoc_files=()

function path_to_adoc_path () {
  # get the new filename from the second to last field $(NF-1) of the path of the original
  dest_filename=$(echo $1 | awk -F '/' '{ print $(NF-1) ".adoc" }')
  # dest_path is the path to the antora modules ROOT directory
  echo ${DEST_ROOT}/content/modules/ROOT/pages/${dest_filename}
}

for f in $SOURCE_LIST
do
  echo $f
  dest_path=$(path_to_adoc_path $f)
  echo $dest_path
  adoc_files+=($dest_path)
  # convert to asciidoc, in the correct place
  # add a heading offset, because the md has = 0, and asciidoc needs = 1
  kramdoc --heading-offset=1 --format=GFM --wrap=ventilate --imagesdir='../assets' \
    --attribute=_sandbox_id --output="$dest_path" "$f"
done

# Copy the images
cp -vr ${INSTRUQT_ROOT}/assets/* ${DEST_ROOT}/content/modules/ROOT/assets/images

####
# Make the antora yaml
####

# Use yq to edit the default-site.yml to match the instruqt yml

# default-site.yml

# read values from the instruqt yml
title=$(yq '.title' ${INSTRUQT_ROOT}/track.yml)
echo "title: ${title}"
my_url=$(yq '.url' ${INSTRUQT_ROOT}/track.yml)
url=${my_url/#null/'https://demo.redhat.comx'}
echo "url: ${url}"

# Make the antora site.yml
yq -i ".site.title = \"${title}\" | .site.url = \"${url}\"" ${DEST_ROOT}/default-site.yml

# content/antora.yml

yq -i ".title = \"${title}\"" ${DEST_ROOT}/content/antora.yml

# content/modules/ROOT/nav.adoc
#* xref:module-01.adoc[1. RPM Native Container]
rm -rf ${DEST_ROOT}/content/modules/ROOT/nav.adoc

for f in ${SOURCE_LIST}
do
  # get the title
  echo "Getting values from: $f"
  my_title=$(yq 'select(document_index == 0).title' $f)
  # set a title if my_title is empty
  title=${my_title:-$(echo $f | awk -F '/' '{ print $(NF-1) }')}
  echo $title
  # get the path
  dest_path=$(path_to_adoc_path $f | xargs basename )
  echo "* xref:${dest_path}[${title}]" >> ${DEST_ROOT}/content/modules/ROOT/nav.adoc
done
