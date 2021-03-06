#!/bin/bash

set -x
set -e

branch=$1
server=$2
password=$3
transformer=$4
apikey=$5

if [ "$transformer" == "true" ]; then
    isopath="xe-phase-transformer/main_transformer.iso";
else
    isopath="xe-phase-1/main.iso"
fi

export PATH=/local/bigdisc/packer-bin:$PATH

boxbasedir=/usr/local/builds/vagrant
resultdir=/local/bigdisc/vagrant
VERSION=`readlink /usr/groups/build/$branch/latest`

# Make a tmp dir to construct the box
boxdir=$boxbasedir/tmp-$branch

if [ "$transformer" == "true" ]; then
	xva=$branch.t.$VERSION.xva
	boxfile=$branch.t.$VERSION.box
else
	xva=$branch.$VERSION.xva
	boxfile=$branch.$VERSION.box
fi

rm -rf $boxdir
mkdir -p $boxdir
packer build -only=xenserver-iso -var "branch=$branch" -var "xshost=$server" -var "xspassword=$password" -var "outputdir=$boxdir" -var "version=$VERSION" -var "isopath=$isopath" internal/template-dev.json
rm -rf packer_cache/*
mkdir -p $resultdir/$branch
mv $boxdir/*.xva $resultdir/$branch/$xva
mkdir -p $resultdir/$branch
echo "{\"provider\": \"xenserver\"}" > $boxdir/metadata.json
cat > $boxdir/Vagrantfile << EOF
Vagrant.configure(2) do |config|
  config.vm.provider :xenserver do |xs|
    xs.xva_url = "http://xen-git.uk.xensource.com/vagrant/$branch/$xva"
  end
end
EOF
cd $boxdir
tar zcf $resultdir/$branch/$boxfile .
cd -

rm -rf $boxdir

pushd $resultdir/$branch
(ls -t|head -n 2;ls)|sort|uniq -u|xargs rm -f
popd

SHA=`sha1sum $resultdir/$branch/$boxfile | cut -d\  -f1`

cat > $resultdir/$branch/$branch.json <<EOF
{
  "name": "xenserver/$branch",
  "description": "This box contains XenServer installed from branch $branch (transformer=$transformer)",
  "versions": [{
    "version": "0.0.$VERSION",
    "providers": [{
      "name": "xenserver",
      "url": "http://xen-git.uk.xensource.com/vagrant/$branch/$boxfile",
      "checksum_type": "sha1",
      "checksum": "$SHA"
    }]
  }]
}
EOF

if [ "$transformer" == "true" ]; then
	boxname=xs-transformer-$branch
else
        boxname=xs-$branch
fi

echo boxname=$boxname


jenkins/create-vagrantcloud-box.sh $boxname $apikey
jenkins/update-vagrantcloud-box.sh $boxname 0.0.$VERSION http://xen-git.uk.xensource.com/vagrant/$branch/$boxfile $apikey


