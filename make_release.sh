#!/bin/bash

OXIRELEASE=$(date +%s)
OXIRELEASEDIR=/tmp/oxiscript_release
rm -rf $OXIRELEASEDIR
mkdir -p $OXIRELEASEDIR

echo -e "Generating new release: $OXIRELEASE"
echo -e "\tEditing setup.sh with release: \c"
	sed "s/export OXIRELEASE=xxx/export OXIRELEASE=$OXIRELEASE/g" setup_pure.sh > $OXIRELEASEDIR/setup.sh
echo -e "Done\n"

echo -e "Copying files to $OXIRELEASEDIR: \c"
	cp -r * $OXIRELEASEDIR
#	cp debian/* $OXIRELEASEDIR
#	cp gentoo/* $OXIRELEASEDIR
#	cp jobs/* $OXIRELEASEDIR
echo -e "Done\n"

echo -e "Removing temp files in $OXIRELEASEDIR: \c"
	rm $OXIRELEASEDIR/setup_pure.sh
	rm $OXIRELEASEDIR/install_pure.sh
	rm $OXIRELEASEDIR/make_release.sh
	rm $OXIRELEASEDIR/install.sh 2>&1 
	rm $OXIRELEASEDIR/install.sh.md5 2>&1 
echo -e "Done\n"

echo -e "Creating oxiuserscripts.tar.gz2: \c"
    tar -C user -czf $OXIRELEASEDIR/oxiuserscripts.tar.gz2 .
echo -e "Done\n"

echo -e "Creating definitive install.sh file:"
	sed "s/INSTALLOXIRELEASE=xxx/INSTALLOXIRELEASE=$OXIRELEASE/g" install_pure.sh > install.sh
	echo "PAYLOAD:" >> install.sh
	
	echo -e "\tGenerating tar content for install.sh: \c"
		tar -C $OXIRELEASEDIR -zc . | uuencode - >> install.sh
	echo -e "Size: $(du -h install.sh | awk '{print $1}')\n"

echo -e "Calculating MD6 Sum: \c"
	md5sum install.sh > install.sh.md5
echo -e "Done"

echo -e "Making file executable: \c"
	chmod +x install.sh
echo -e "Done"

echo -e "Removing tmp dir: \c"
	rm -rf $OXIRELEASEDIR
echo -e "Done"
