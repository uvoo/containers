#!/bin/bash
set -e
script_dir=$( dirname -- "$0")

processTemplates(){
  set +eu
  for template_file in $(find . -type f -name "*.envsubst"); do
    dst_file="${template_file%.*}"
    echo Processing envsubst file $template_file to $dst_file with env variables.
    echo "Testing & display unset envirnomental variables for $template_file file."
    for i in $(envsubst -v "$(cat $template_file)"); do
      if [ -z ${!i} ]; then
        echo "\$$i variable is unset."
        exit 1
      fi
    done
    set -eu
    envsubst < $template_file > $dst_file
  done
  # for file in $(find . -type f -name "*.jinja"); do
  #   echo Processing jinja file $file with env variables.
  #   python3 ${script_dir}/createFileFromJinjaUsingEnv.py -t $file
  # done
}

processTemplates
