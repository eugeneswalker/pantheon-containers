TE=`printf '%(%Y%m%d)T' -1`
REPO=`git config --get remote.origin.url`
COMMIT=`git log -1 --format="%H"`

docker build \
  --build-arg DATE=${DATE} \
  --build-arg REPO=${REPO} \
  --build-arg COMMIT=${COMMIT} \
  -t ecpe4s/rhel8-base-x86_64:${DATE} .