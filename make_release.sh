#!/bin/bash

OXIRELEASE=$(date +%s)
OXIRELEASEDIR=/tmp/oxiscript_release
rm -rf $OXIRELEASEDIR
mkdir -p $OXIRELEASEDIR
find . -name "*~" -exec rm -v {} \;

echo -e "Generating new release: $OXIRELEASE"
echo -e "\tEditing setup.sh with release: \c"
	sed "s/export OXIRELEASE=xxx/export OXIRELEASE=$OXIRELEASE/g" setup_pure.sh > $OXIRELEASEDIR/setup.sh
echo -e "Done\n"

echo -e "Copying files to $OXIRELEASEDIR: \c"
	cp -r * $OXIRELEASEDIR
echo -e "Done\n"

echo -e "Clearing some tmp files: \c"
	find $OXIRELEASEDIR -name "*.swp" -exec rm {} \;
echo -e "Done\n"

echo -e "Removing temp files in $OXIRELEASEDIR: \c"
	rm $OXIRELEASEDIR/setup_pure.sh
	rm $OXIRELEASEDIR/install_pure.sh
	rm $OXIRELEASEDIR/make_release.sh
	rm $OXIRELEASEDIR/install.sh 2>&1 
	rm $OXIRELEASEDIR/install.sh.md5 2>&1 
	rm $OXIRELEASEDIR/publish_release.sh 2>/dev/null
	find $OXIRELEASEDIR -name "*~" -exec rm {} \;
echo -e "Done\n"

#echo -e "Creating oxiuserscripts.tar.gz2: \c"
#    tar -C ../oxiuserscripts -czf $OXIRELEASEDIR/oxiuserscripts.tar.gz2 .
#echo -e "Done\n"

#echo -e "Changing file rights: \c"
#	chmod -R 644 $OXIRELEASEDIR
#echo -e "Done\n"

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

#echo -e "Copying file to webserver: \c"
#	cp install.* /var/www/munin
#	chmod 644 /var/www/munin/install.*
#echo -e "Done"
