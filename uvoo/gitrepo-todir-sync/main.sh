#!/usr/bin/env bash
# Clones repos into directories.
# ALternative https://github.com/presslabs/gitfs
if [ -n ${SINGLEBRANCH} ]; then
 SINGLEBRANCHCMD="--single-branch"
fi
if [ -n ${QUIET} ]; then
 QUIET="--quiet"
fi

if [ -z ${SETOPTS} ]; then
  SETOPTS="-eu"
fi
set ${SETOPTS}

if [ -z "${REPO_URI_SRCS}" ] || [ -z "${REPO_DIR_DSTS}" ]; then
  echo "E: Requires .env variables REPO_URI_SRCS and REPO_DIR_DSTS."
  exit 1
fi

if [ -z ${INTERVAL} ]; then
  INTERVAL=600
fi

if [ -n ${BRANCH} ]; then
 BRANCHCMD="--branch $BRANCH"
else
  BRANCHCMD="--branch main"
fi


authURL(){
  REPO=$1
  if [ "${REPO_USER}" ] && [ "${REPO_PASS}" ]; then
    sedcmd="s^//^//${REPO_USER}:${REPO_PASS}@^"
    REPO=$(echo -n ${REPO} | sed -e "$sedcmd")
  fi
  echo ${REPO}
}


loopRepos(){
  IFS=', ' read -r -a repo_uri_srcs <<< "$REPO_URI_SRCS"
  IFS=', ' read -r -a repo_dir_dsts <<< "$REPO_DIR_DSTS"
  for index in "${!repo_uri_srcs[@]}"; do
    src="${repo_uri_srcs[index]}"
    src=$(authURL $src)
    dst="${repo_dir_dsts[index]}"
    cloneOrPull $src $dst
  done
}


cloneOrPull(){
  REPO=$1
  DIR=$2
  mkdir -p $DIR
  cd $DIR
  set +e
  git -C .  rev-parse 2>/dev/null
  ec=$?
  set -e
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  DISPLAYREPO=$(echo $REPO | cut -d"/" -f4-)
  if [[ $ec -eq 0 ]]; then
    echo "$ts Pulling $DISPLAYREPO to $DIR"
    git pull $QUIET
  else
    echo "$ts Cloning $DISPLAYREPO $BRANCH to $DIR"
    git clone $QUIET ${SINGLEBRANCHCMD} ${BRANCHCMD} $REPO .
  fi
  cd
}


chmodDir(){
  if [ -n "${CHMOD}" ]; then
    git stash
    find . -type f | grep -v $CHMOD_EXCLUDE | xargs ${CHMOD}
  fi
}


while true; do
  loopRepos
  sleep $INTERVAL
done
