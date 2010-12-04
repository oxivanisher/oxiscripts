#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1291488092

red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m' # No Color

echo -e "\n${BLUE}oxiscripts install (oxi@mittelerde.ch)${NC}"
echo -e "${cyan}--- Installing release: ${CYAN}$INSTALLOXIRELEASE${cyan} ---${NC}"

if [[ $EUID -ne 0 ]];
then
	echo -e "${RED}This script must be run as root${NC}" 2>&1
	exit 1
fi

echo -e "\n${cyan}Checking needed apps: \c"
if [ -z "$( which lsb_release 2>/dev/null )" ];
then
	if [ -n "$( which aptitude 2>/dev/null )" ];
	then
		aptitude install lsb-release -P || exit 1
	elif [ -n "$( which emerge 2>/dev/null )" ];
	then
		emerge lsb-release -av || exit 1
	else
		echo -e "\n${RED}Unable to install lsb_release${NC}"
		exit 1
	fi
else
	echo -e "${CYAN}Done${NC}"

	case "$(lsb_release -is)" in
		Debian|Ubuntu)
			LSBID="debian"
		;;
		Gentoo)
			LSBID="gentoo"
		;;
#		RedHatEnterpriseServer|CentOS)
#			LSBID="redhat"
#		;;
		*)
			echo -e "${RED}Unsupported distribution: $LSBID${NC}; or lsb_release not found."
			exit 1
		;;
	esac

	echo -e "${cyan}Found supported distribution family: ${CYAN}$LSBID${NC}"
fi

if [ -z "$( which uudecode 2>/dev/null )" ]; then
	if [ "$LSBID" == "debian" ];
	then
		echo -e "${RED}Installing uudecode (aptitude install sharutils)${NC}"
		aptitude install sharutils -P || exit 1
	elif [ "$LSBID" == "gentoo" ];
	then
		echo -e "${RED}Installing uudecode (sharutils)${NC}"
		emerge sharutils -av || exit 1
	else
		echo -e "\n${RED}Unable to install uuencode${NC}"
		exit 1
	fi
fi

echo -e "${cyan}Creating ${CYAN}$TARGETDIR${cyan}: ${NC}\c"
	mkdir -p $TARGETDIR/install
	mkdir -p $TARGETDIR/jobs
	mkdir -p $TARGETDIR/debian
	mkdir -p $TARGETDIR/gentoo
	mkdir -p $TARGETDIR/user
echo -e "${CYAN}Done${NC}"

echo -e "${cyan}Extracting files: \c"
	match=$(grep --text --line-number '^PAYLOAD:$' $0 | cut -d ':' -f 1)
	payload_start=$((match+1))
	tail -n +$payload_start $0 | uudecode | tar -C $TARGETDIR/install -xz || exit 0
echo -e "${CYAN}Done${NC}"

echo -e "${cyan}Putting files in place${NC}\c"
function movevar {
	oldvar=$(egrep "$2" $TARGETDIR/$1 | sed 's/\&/\\\&/g')
	newvar=$(egrep "$2" $TARGETDIR/$1.new | sed 's/\&/\\\&/g')
	if [  -n "$oldvar" ]; then
		sed -e "s|$newvar|$oldvar|g" $TARGETDIR/$1.new > $TARGETDIR/$1.tmp
		mv $TARGETDIR/$1.tmp $TARGETDIR/$1.new
		echo -e "  ${cyan}$1:  ${CYAN}$( echo $oldvar | sed 's/export //g' )${NC}"
	fi
}

if [ -e $TARGETDIR/setup.sh ]; then
	echo -e "\n${cyan}Checking old configuration"
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh.new

	movevar "setup.sh" '^export ADMINMAIL=.*$'
	movevar "setup.sh" '^export BACKUPDIR=.*$'
	movevar "setup.sh" '^export DEBUG=.*$'
	movevar "setup.sh" '^export SCRIPTSDIR=.*$'
	movevar "setup.sh" '^export OXIMIRROR=.*$'
	movevar "setup.sh" '^export OXICOLOR=.*$'

	mv $TARGETDIR/setup.sh.new $TARGETDIR/setup.sh
else
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh
fi

if [ -e $TARGETDIR/backup.sh ]; then
	mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh.new

	movevar "backup.sh" '^\s*MOUNTO=.*$'
	movevar "backup.sh" '^\s*UMOUNTO=.*$'

	mv $TARGETDIR/backup.sh.new $TARGETDIR/backup.sh
else
	mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh
fi

#mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh
mv $TARGETDIR/install/init.sh $TARGETDIR/init.sh
mv $TARGETDIR/install/virtualbox.sh $TARGETDIR/virtualbox.sh

mv $TARGETDIR/install/debian/* $TARGETDIR/debian
rmdir $TARGETDIR/install/debian

mv $TARGETDIR/install/gentoo/* $TARGETDIR/gentoo
rmdir $TARGETDIR/install/gentoo

mv $TARGETDIR/install/user/* $TARGETDIR/user
rmdir $TARGETDIR/install/user

echo -e "\n${cyan}Checking old jobfiles${NC}"
for FILEPATH in $(ls $TARGETDIR/install/jobs/*.sh); do
FILE=$(basename $FILEPATH)
	if [ -e $TARGETDIR/jobs/$FILE ]; then
		if [ ! -n "$(diff -q $TARGETDIR/jobs/$FILE $TARGETDIR/install/jobs/$FILE)" ]; then
			mv $TARGETDIR/install/jobs/$FILE $TARGETDIR/jobs/$FILE
		else
			echo -e "${RED}->${NC}    ${red}$FILE is edited${NC}"
			mv $TARGETDIR/install/jobs/$FILE $TARGETDIR/jobs/$FILE.new
		fi
	else
		mv $TARGETDIR/install/jobs/$FILE $TARGETDIR/jobs/$FILE
	fi
done
rmdir $TARGETDIR/install/jobs/

find $TARGETDIR/install/ -maxdepth 1 -type f -exec mv {} $TARGETDIR \;
rmdir $TARGETDIR/install

echo -e "\n${cyan}Setting permissions: \c"

	chmod 640 $TARGETDIR/*.sh
	chmod 755 $TARGETDIR/init.sh
	chmod 644 $TARGETDIR/functions.sh
	chmod 644 $TARGETDIR/virtualbox.sh
	chmod 644 $TARGETDIR/setup.sh
	chmod -R 750 $TARGETDIR/jobs/
	chmod -R 755 $TARGETDIR/debian/
	chmod -R 755 $TARGETDIR/gentoo/
	chmod -R 755 $TARGETDIR/user/

	chown -R root.root $TARGETDIR

echo -e "${CYAN}Done${NC}\n"

echo -e "${cyan}Enabling services${NC}"
if [ "$LSBID" == "debian" ];
then
	if [ ! -e /etc/init.d/oxivbox ];
	then
		echo -e "  ${cyan}Activating debian vbox job${NC}"
		ln -s $TARGETDIR/debian/oxivbox.sh /etc/init.d/oxivbox
	fi

	echo -e "  ${cyan}Activating weekly update check: \c"
	ln -sf $TARGETDIR/debian/updatecheck.sh /etc/cron.weekly/updatecheck
	echo -e "${CYAN}Done${NC}"

	if [ -e /var/cache/apt/archives/ ]; then
		echo -e "  ${cyan}Activating weekly cleanup of /var/cache/apt/archives/: \c"
		ln -sf $TARGETDIR/debian/cleanup-apt.sh /etc/cron.weekly/cleanup-apt
		echo -e "${CYAN}Done${NC}"
	fi
fi
##monthly cron$
echo -e "  ${cyan}Activating monthly backup statistic: \c"
    ln -sf $TARGETDIR/jobs/backup-info.sh /etc/cron.monthly/backup-info
echo -e "${CYAN}Done${NC}"

##weelky cron
echo -e "  ${cyan}Activating weekly backup cleanup (saves a lot of space!): \c"
    ln -sf $TARGETDIR/jobs/backup-cleanup.sh /etc/cron.weekly/backup-cleanup
echo -e "${CYAN}Done${NC}"

#daily cron
echo -e "  ${cyan}Activating daily system, ~/scripts and ~/bin backup: \c"
    ln -sf $TARGETDIR/jobs/backup-system.sh /etc/cron.daily/backup-system
    ln -sf $TARGETDIR/jobs/backup-scripts.sh /etc/cron.daily/backup-scripts
echo -e "${CYAN}Done${NC}"


if [ $(which ejabberdctl 2>/dev/null ) ]; then
    echo -e "  ${CYAN}Found ejabberd, installing daily backup and weekly avatar cleanup${NC}"
    ln -sf $TARGETDIR/jobs/cleanup-avatars.sh /etc/cron.weekly/cleanup-avatars
    ln -sf $TARGETDIR/jobs/backup-ejabberd.sh /etc/cron.daily/backup-ejabberd
fi

if [ $(which masqld 2>/dev/null ) ]; then
    echo -e "  ${CYAN}Found mysql, installing daily backup${NC}"
    ln -sf $TARGETDIR/jobs/backup-mysql.sh /etc/cron.daily/backup-mysql
fi

echo -e "\n${cyan}Activated services${NC}"
for FILE in $( ls -l /etc/cron.*/* | grep /etc/oxiscripts/jobs/ | awk '{print $9}' | sort )
do
	shedule="$( echo $FILE | sed 's/\/etc\/cron\.//g' | sed 's/\// /g' | awk '{print $1}' )"
	file="$( echo $FILE | sed 's/\/etc\/cron\.//g' | sed 's/\// /g' | awk '{print $2}' )"
	printf "  ${CYAN}%-30s ${cyan}%s${NC}\n" $file $shedule
done


# add init.sh to all .bashrc files
# (Currently doesn't support changing of the install dir!)
echo -e "\n${cyan}Checking user profiles to add init.sh${NC}"
function addtorc {
	if [ ! -n "$(grep oxiscripts/init.sh $1)" ];
	then
		echo -e "  ${cyan}Found and editing file: ${CYAN}$1${NC}"
		echo -e "\n#OXISCRIPTS HEADER (remove only as block!)" >> $1
		echo "if [ -f $TARGETDIR/init.sh ]; then" >> $1
		echo "       [ -z \"\$PS1\" ] && return" >> $1
		echo "       . $TARGETDIR/init.sh" >> $1
		echo "fi" >> $1
	else
		echo -e "  ${cyan}Found but not editing file: ${CYAN}$1${NC}"
	fi
}

if [ ! -f /root/.bash_profile ];
then
	echo -e "#!/bin/bash\n[[ -f ~/.bashrc ]] && . ~/.bashrc" >> /root/.bash_profile
fi
touch /root/.bashrc
addtorc /root/.bashrc
for FILE in $(ls /home/*/.bash_history); do
	tname="$( dirname $FILE )/.bashrc"
	username=$( dirname $FILE | sed 's/home//g' | sed 's/\.bash_history//g' | sed 's/\///g' )
	touch $tname
	addtorc $tname
	chown $username.$username $tname
	chmod 644 $tname
done


install=""
doit="0"
echo -e "\n${cyan}Checking optional apps\n  \c"
BINS="rdiff-backup fdupes rsync mailx screen"
for BIN in $BINS
do
	if [ ! -n "$(which $BIN 2>/dev/null )" ]; then
		echo -e "${RED}$BIN${NC} \c"
		install="$install$BIN "
		doit="1"
	else
		echo -e "${cyan}$BIN${NC} \c"
	fi
done
echo -e "${NC}"

if [ "$doit" == "1" ];
then
	if [ "$LSBID" == "debian" ];
	then
		aptitude install $install -P
	elif [ "$LSBID" == "gentoo" ];
	then
		emerge $install -av
	fi
fi

echo -e "\n${BLUE}Everything done.${NC}\n"
. /etc/oxiscripts/init.sh
exit 0
PAYLOAD:
begin 644 -
M'XL(`%R+^DP``^P\^5OC1K+SJ_U7U,A.P"SRQ3%O89T,PS'#M^'X,#/)>S#+
MMJ6VK8>NZ+`AX/W;7U5W2Y9E<P<F>4%?,ECJ[NJJZJKJKD.JUMX\^U7'Z]W*
M"OUMO%NIJ[]-\5Q=;QJ-Y7>K*_65E:5E?/YNN?[N#:P\/VIOWL1AQ`*`-]Z%
M=6N_N]K_I%>U-K""*&9VQ[NHAOUGF8,6>'5Y^8;U;RROK#8GU[_1;&`SU)\%
MF]SU%U__TMM:QW)K'1;VB\52%6H\,FI(:V@$EA^%M6[L&I'EN6&5.O`+WPLB
M./AEM[UYM'MXW-[YO+]YO'NPWVYIY1E/U[P+?8"2I?=XI`^<4"LF\"#7`E?%
M@M6%$]#*#0U:+=!TO<]M7X.OZQ#UN5LL%+C1]T`+^]Z0G@"-\KK`;!OBD`<A
M(';<B"#PO$C#[@&/XL"%>K'0M?!_+X#/[>TCL%PHS]LAU/J>PROKQ8+I86<Q
MM\Y!$X]K9>I:JWZ1NO'!NZCM,:-ON3PDA+"_0DGB1.,$3+T!NFYXMA>T7#[@
M`=P%K:+!-0S[ELTAX,R$+WL$7**4!4X`3J/RESU--KL<_Q)9XN?HB2L3Q*YK
MN;U;5BC3XX$K1<NC1H.`GU\8/P067R`;>@'W86R-:E^049^0*38/PZ19'\B_
MU\"&YS!WY0>6&P$B<AIIY?V=T=R3>$&F@*1Q!A.2I@=03R.09-C?V-N>)MNY
M-+S8C5IU*9I?]J1@=BW7E%(#NLL<+N?1HTN?@YE*:S*X/#]?5K_A;XU*!9L&
M#@W#%H$%2HSBE;Y3&_.+.%41<$AS[NB\)/NFPM@FPF@YL3L+H2R!K(&23N+.
M"92W/^]N(0D<ZO!US!K5JJE!DH/E^6'?8XZ%RC#1=XR>:A</R_.D,$8?T$1Q
M[D+SAYK)!S4WMNT*Z*;3AK+D@:XF@73$A$1EQ@$.#)-A-`DM4(';H;@)XX1&
MT`W"]GGGUR"KVJFTJ65&CH%6ET8H*V["2EP=;6^-]CU<F#9TL;<)0ROJ"V-)
MD'&)&N6K_<V1)D3P:9KB^3<IBFAYB)YX_HUJ`GB--87N'J(LU!_U!=1UH]8D
M'1Z@.V.8]]6@9$1&CSS?OTF/DMZW:!-DKGNK%>2N*17+=WBPN.OG%DHT`4Q$
M?H^YK,<K8'AN%'@VKK4:`LSP+=\;\J`31Y$WB9U:?<$RTL1LVU-5\@DXHGKF
M,)1ZFJS"3%6EQ@GV/T9GY8Q/4MN`A_R&#2YINK_BBA%_4<V]90?\:VBN6/P_
MI+X*S/[46DK$SE92U7)_'15\>U71OZ2*BDW+ZW;_D%J:(*=]>STM%DN)?C$3
MIP^MT(M]DT7\\2J<`S1#E7,][J_2JC^1A/+/`Y?9(($!0H/(`R,.`HZJ,?:E
M8<"#$&>?=D,_;&S^\_/A[DZ[5<9_B@7Q:^[4G2MF_0KCDKFC-F<!12UZRDS,
MA:DSD3$;N;A.QF6=K<MC'SYQ20?.+;V:.6?T--KL<^.<L)I78E@A*1XX:W!J
M:`)@Q$.R2RC>NCTAX6,1!8I5#!S+[7IR-.BZ(V,T%)=A'9MK20S"')C)SUH<
M!K6PSP)>RP4N/L8XZ89I6C)XABM32:-,KI!JPNK&8)+DN``"*11P2!&X^18^
MN^(G4EVM5I-5*!2\./+C.TG-**.@%.EA483$@HNZIU4RKN]="+E>E""58I&Z
MKE*64@$KYF-P4QM,)D!VDZ%/I"F/V*;MA20##C>MV!$"JNS]U>9_;^R/1``M
M13'/)X%3GDL(D2MPM.(/66KBH?+>G<&#1CZH<]6SS6+ARX>#7[YL'R$U&>RO
MH4_A1!2U1AHZV_9@[J2N__UK=8%T*,-"P:(='DGM9@9-"[OM@XQP#5&?42?\
MP$-@8=@RO6C-X3T&^L'#".Q'D;]6JYG>T+4]9E8SZ0<OZ&4!E!5E,R"=)6T$
MLI@>79XJ6[DC35[(#GSNWE?($ACW$34/X3Y>TM)-LT`_;S'H<'^+GC#T9J.>
M8]7]K/NX]X-L/)Z3)+Y[RNA!W@[AOBIMF>J8;@4W:?Q#+>.CUR1G`_&X\:TS
M/I-7M7:TO;&UM_V<<]R>_\.KF<O_-NK-E7>O^;^7N(X]TP.T\\72SNXO>]M_
M,.E\O9[[JJ)/U[&8^YQE(`^N_VC45Y<:K_4?+W&EZV_8G+FQKS,_^KWK0.ZR
M_ZO-E=SZ+RW7&Z_V_R6N;/W'7=4?I>.^%<+_>AT0PA**&$05Y0<,/"/Q8GOW
M?[8_;.\<'&WC0<O$@U:(!Z<!"VJBN8:251/GS0$/9QX/Y:%]]H#:@@H]=D$W
MN<TC#LT?OF^(.3=VCH7_\X@IB\(C+X\QA[<M>2N`DGLNG7,\_"*/N(X>K]6]
M9*:#YV)MX_`8-FDBR1`\4-)!=+[OA1$Y'14-M+;U&X<.Q\,T!9_&\YRZHH5U
M(^%`I#-JR(67W(13_;=<ZW=7?'7=H?\KS>7I^J^EI5?]?XDKJ_\EV!*R`"0+
M(&T`:CW\A'XZ]+@;>1[8UCF'PW:#GF_VF=N3D<@AJBZ595F1S:DHZQ=`N48=
M878(10,5!STSE.Z]$<).W<`+ZK-P'5P,HH7K;;JY9N+?<_%OST7W?6$Z:'YX
M=+!W>'RV>;"WM[&_U9J3?J)+P<#ZTM+7^GKYBKSLT?ORU:>#]C&E/K[[KKHP
M6BM?'?Z\52M_.MC;KOUG=(J'$FUN"OKZ>OI(QKT?BL#9?:=?6CH]G8T`#YE1
M+**'>B9KR;J,XG'(\3:/0#SJQC:M`MH;^Y*,3OHP93N>Z,&T`M$0BL@-6CT=
M_5E&=HP"%R%8$;K.0Q<ZL65'.EJTI!G'6FX840@)%S,6H36Q-VSM'B'=/QT<
MM:L`Q\$EA9L1E)`!?J&BT5W+)@A=*T`G'3M$#&6&F0/F1B+<T15A$PI:*Z<9
MX'.8B68K8>S97J=#,V=02><0(2UL9<%EM1BR+C\CREM2RFJUDW^=K#';C9VU
MKU]K/XZ0K24(&8HU&5WJ4G189/3/['[8TK3BR0GH7?A/K8H<.U,LH[P.?/\]
M9#J6K]*;47G^'Q/]*PF4')_NA)+KK^#\!MEN(+$Y385E`B+N?#<N=(6@B?C/
M!+Q6"Q;$4XV800&AE(>C!87R6/ZB(.9BJRQ?I0]'D$MZE6#;I3@Y*$PH?F2'
MBX#DX0(?!KR+:S[)XA+N"O_U]RD-D/FVJ05!K&[(LR47'S#*/V6XT9F$,:W+
MW$YGF[%PCY@OOYQ3@RGK-$EI^8HRD&)1ZK?,BOK>FCL](<-Q4F^L+S6<TZ^G
M_<R#97P`IS_#:3EY6*<G8Q,SE?&;!;9)8./W,R`/9T`N/0G<R>F_)0M.RS\F
M^3V5[Y+1U[E3?H(@6J<5_%%WYM8%#9FV!K;-RS;D6]<Z_3>!OHD!6=XSVV(A
M2FAKC@IW5=4NBR-O+M>%3$UK3L;01;<XZ3?!SP>M94DDG$2I\GL8$KE#3A'#
MN0CZ;)#HT`UK1=R4ZWR_M97]AY/]D17$C9+`0>XCZ6F_.)$8Y[_*Q+@Z"3\F
M)TISZ+'?"YC)*5^8289FFR@)>F<6M)`;I#?@^AHW!CRR-&8U-]/F)C6/TY^R
MRA-=!"N*<6[5OU@8%9].I-Z\A4Q$Z5Z$RGQO'D'M!:EHW$9%XY%4R(3X[42(
M[#O2\++.T%_P2OT_R7.#DNDO'?]9?C<=_UEY]?]>Y'I(_$<DP:@W*BJE`I6>
MPK@N2,53M/+\5%_=I!IW_=?$0B5I:4W=FXM:1:/HBU:']!%N/"X?XM9$+@"S
M;?D(78J`.QYND\PUJ8L7I4.JVCUB-I\EWNV(17$X';.9@7V"-.(O"*F\=)SF
MN:Y4_W'5!\_T#N`=^K_Z#G4^%_]919/PJO\O<)7>0O8%P%()/FQ_W-V'W?W=
M8_QGYP!/B(>!-[!,'JZ-#Y9*6K#QB/\:6P$W=5%Q*;J4;<]@]EDWA#+I:<3I
M)W4W@\'D",^7,.\8T>Y[L9V=`4>@-<BV))#2EBW>9;$=90<U80F6866B,1U7
MAP:L2HA!I&]Q:0+1]JV!`%$3[ZF,Z9[H(:]9_9"AV_M;&786#S>./[5J(3)]
MK2;^$:4%Z2_\4=P\V-_9V?UINY6WQXF2&I[;I;.[[?7.3(8<<\^<L#=?$0:1
M'B9U.NJQ%9)GX5-IM!M124?F9YL%/4[1H@_<1I?$"H&A^^%?4K@%[:@#W<!S
MT$_J"&,*2]6ZOK(HO'L*^B`F`^Y:W#5$8*?#C',=8=&YDP<4V=GMJE)%9<"3
M4D3JG0+UE8115[Q-MYU%!(6/+F%(E:4=$;8RDWA0M5B<I!^0TJMQZ:C^FSR7
MYJMSU;&S4<QZA.,1S>D1*L!'X-:T')P$"OTIYCL#0J.:C_R2/!+3"?!0?B]@
MXZYM6YT:\E+$\/6Q%S>]GZL@_XR6B;?`BT5<)-PRS\+8YP$%ZP2^!28`M\KH
M9^6\0XH7*7X4B-@NL^PXX()6K9U`P76V!I;->[C2@;("B21I<$H^@7:JE>4T
MIQK('U6-/!GTWY:)7/%:I40G\PIE3A`TI2C008?%<GL:.D,V"R-1I*3E*E8-
M%DVQ(ZMHW_"MR\2_>INM/L??"2T3CM:4D&EI&512EUG`_U(^J$;U=&IP\CKB
MMWVE$[[U.YV_#P(/?JES>CTFJMKQ"$PA*!+OJGR;LR"5@+NFZ%Z7NN+Y4E7R
M^C%^]U#J/:2OMQ<+):`Z?IS<P+&FQ\7>$067T&>!"=SUXEZ?[!:9==\R1;B?
MM@W'"BE1L$@00@^0DW3(1KW%MAZ2+38G&B01H<=A9(U?#R^6"LG$H/M0/MS=
MHDT0TL.X$V,W/,U3>`.-3:O\8PY9N<U%N(,+'"6JB_@W1%N4G;K/0MQ-B-&(
M*K$"[9##7&2$?8EF+HJX@U8`#4NI0!6'-BH@4NIUIW`K;VUL[QWL9UR@=2J+
M+!7&0-!:X)E$W<'?\)B!%@,[A#9']Z=>K:_0W4FFCVY'T%1&E4H2+3?FU">[
MO@UZD.X/)55Q?4+GIRAKE*?EB'IJD\)"@XH)-'$S2CVYDB94OC&V-%/V_7/(
M>GQ-VE"QPYB)_4R,^I6PVM?$ZFO$1-V0]S5*C'M3A"-%JE#LA2)/*'I2"+V0
MWY"@3+MB0710$$@<1/:.IKE]D.?GQRBL[AJ6QA)IX`V3$UD"#HH,KOZM@E,9
M2[+H?87_?@<C*(WE#>4:,?%MB]/)+`J0\Z2XH<\,OHC3X8:%2J9,2G;Y4ZM+
M"Q;&AI&*P)Y0I'U4)%+"Y.L,\X@;GEAP8K%?"+)P:Y49DC%DE`3B0N9),S?7
MA'!,SF6BH5P$9J..DH:F[,#)PBBLIO,VIN==RLTR9`&A/6L6"@@HJL8@EZ29
MO&VH7#N(W7/7&V;/'<F!3*SP0N5^.C`V5P]2@T*:`)Z>Q)6?.*%3DWR^"+[-
M26>$$6;0B8EBQ<+[^'_5FDSL_\'J_][5FZ_U?R]QI>O_[>I_ENM+2_GX3_.U
M_N]EKLGZGX^RR"=7__.GRQ#*E--TO@K/0[/R=-.9J-M3C#=G&!M_N.PA=WC0
MXZ#K*E:OZR87B6R7#ZEP9^@%M@DZ&]S$A]^HF@0W4[@WI#]<[C'%/+QTC?O3
M2;V?2(OG1Y9C_393HI.V1U%B<E^4G,JXRP!O]8!3&9=Y?_H2&+GV27!/9`!N
M+N<\<+D]BP-IXT-8H-Q*%#I0@RT'CUYWDIV/\*AMKT?93BA?O1\]D5+!2@T]
ML2R98O8>CT*YSB5%1%JJ7&[,K$HN(2K3[)(+_A!6X8``R*GT`H;^>W@9X@U5
M!88PSR4XW<+[,*+C8UB9P41$>6OW"(D75=61X]>(/X+AV$1A-&P6<33JMDX/
MI?];2"O!\WS0J*LF?.!"X(`>=)'LVH*X3TJY;QLCB=LDXO`@C"R<+ZO:;?T'
M*`L(%4TB(CZ3-R'\TU0_<=T=1G6++G.-F5J>:7["WI7=N5*[D7FFA._NG2SS
M)(&3>:3,`7T3X?]'=O/UNNNJ3AC"YYGCKO/_TKN\_]=877ZM_WB1:_+\[P56
MSQ(EV)=PR`:>#5N6';N]16A;!O/A.&#T10R5P\SF+-<R*4SZ17[#AOCF"EHV
M%LW)]!WS?>Z:7,2OR<D(F-,-15Q8[>72(O]S^VC_C`KG6UKO7!.05,8VZ4=Y
M&:LG.U*V%/<GVM]E:UBS+3>^T)O556V<[*5]CQN1AQLA;5OCZ;T!#VQV6?PH
MH!U\^0FWFLQ^EYY2=-618'ZFL&#(#:MK(36B#MT2Z4L6X=%$$MCAV31K.M]X
MG@^[M+L(=M5BD].K_^EO9CKJSCGOAE5^$2VK>][LAL:YNJ&?U-C,W2_E[I<3
MI$W>Q144KW,H5K*@%SN(9(+8QM%'Q$K7[?B<ZF*Q*9;<SO+RKN'EJ_'="*%0
M9YDANTH7=TU7@3;JD+(GX7(K`2$7A/JXGHY=<.,^UQW/C%%2Q$"16";DVH<_
M;;0_P48.(_DXI2OT;13VELMPHV3VF31_FG1^4^ER'!)*^7Z!`K.YM]5*4Q$I
M_?3U(!R[DSK&)7IQ`\]',N\B=W,5'"S/4[);Z$2Y7H%_G.B=:UT7Q^ROUR>Z
M@3=B!Z8;'V^<P`\\GP=??Q")WMXY(AN=V58G3)(Z!JDJ<H`8_GZDI8]:ZF,K
M'7$RNZ(N(Y&82+)U.M7R=T83N3G;-.7#Y$A*29[Y_1TZJ30KD!Q050GVN&TY
M;5M:A]%<)M&%D$(Z5>FQPM]AY_Q,+7"609MTJ)>O>N2T4KN=3/7+)H*3L^2D
MW!0+2D)$X98G@QEZ3_UU@"*3O\<8:?4>,_"QXU`0;E[FB36FHV(ZP8W0L6MN
M"GJ6IBS%^QPR8YZ1Q&3:2B)>=TYC3TTC*$F_9$WJM(?;#/Z@PW-6U"E=MTUQ
M%O%1+Q4")TETO8Q%DKF$(K'@+>@7Z6RHP`DSDF"-?*,J=EAX/H\BCML3*EQ@
MH8-)>4#Q'.KU9A/)5YFIJ\9(Y*8*!:6YUWJ'DMBW&3^T6\KMH)^)5M-Q?7U=
M`!*M#P.4GO@5B`3JM>X\`,H4+I3;*`C[E<G$B":9DBA,[A'AI8-;[;DR\+A%
MRITBL?*T,X]76\R/,^7L0%8::$<<)48A_81?-HB`/@N?7-%)\I*[C-$?T3?(
M2;)(G-02OCHWZJH^9^!?77><_Y=65U:G\C_-^NOY_R6NB?,_6E[QBG]2T1%Z
M<6#0^?92?,9_0;RA2459`[X@WM*$L,]M6Y10BVQF["^*5T<-.S9%DIH^P(56
ME='W"$49=PH@&1K&1I^^T!D:OG`$`L,717]XD#:8*.?P;!P34?G(I?J<5A6@
M[0$9$5"5'91:5I4J>#[TZ3A?H@&1^+H5;9&,:D_P)I2UA'WABL#;HGBM=OOX
M\^%;^G5,WY6BG4Z\!9U#EEYY[?-`I9C3<SY]!3F9BDH?&;WU2ACY'IV*"%J&
MN$7QPXKF0K`<$4MS(UG1WB7G2E1;DB<F"!7F+R4#6Z.^A]L0[45AM:@*!P_;
M5#J8J<##X9\(S2&'GO?V[L\ZP`=:RJ%X^XR*W=N['W_>W=_\1#LK<ST\'U+E
MGD?U`T2Z0(,37;P74#42%8\F[W[2^R-#/`10@(J^1DGK*"1%<%TTB]')>\H@
M>M(;<"0X$9+00RZ$R:>XD.4E-`_-)6Q57XXSW'`X_#_VKK0];619?[9^14<H
MU\8>20B\),XA$\>0"<]XR05G;G+C.;8`@35A&R2\Q&%^^ZVE6PO@)1F'G-Q!
MSSD3(W57K]5=75WUUH4%_UB-B^'(\IHC^R\@'-(DME_M_+=8*3M.5@O.^H,0
M;;"2E=+BNL(0T6F0#Z43CL:X.5T,?8)8A#HXA:>;N:<Q2<S+^30Z.81BK_92
M5$K2`!=HH'YQZ-='I`T,!G14;`AE@`FI*Z6B/NJA:0?:RC9U9?NR@F:Q)T./
M[_5-'V.$H,#!OOF?W]9'O7!$^&BLLI2DV(Q?)_.!);['FTZD#CN4*%/UFJ_=
ML(S3'(2>P*MY0VCUYUU(=%B#S!F9:^@U81C1,DR9)DA,@%0;\6S3G+@AA.80
M#7;L2+AFL-EK2^B34Y/3JTTI91(W/8_3B<F^@PW\H%\]V6@R*](R(.>%T8HD
MO76WLZJ2A^\JY*[+6EDG45%H>Q$=37/H;PMGFVJY1+\=^;O>&7DJP3J^>+GW
MMJQ2T`L$I%,I-O$%8@6J%/3B8)>_=Y=%1ASTQ2Y63[:$RE?E1N5%Y43T([J2
MWK+T[MR!0YWL+E2`X$ICH/9&4P%O&(]`]6C<<%+Q&-?XSW@[G0A)I[/C%A)E
M)<?3Z=R8)IES<C#1TNH6(K.3RU96T1V(.5AA$$3SD.<"S+7H'L!KP[SUAI&E
M-/H]8/`@EU<!6J[4XD!KAF2BUY7:$0*U%!T46W"W8`"$CW@/ZO7._6&_AXH'
M6/@['68*A+G\293?[,"B@!@T(UBVN4*1([V(/.]CE_[>J*5ITD&Y4]310;ES
MYGX+J=6R_^C7@V\;!.XK['\*("XN['_F\,CQ1[^-T<`<XIWW@Q\&[O3_S&U-
M^G\6<HOX;W-Y;O?_Y&E!4F*U]OY@]\U.K?8_AU60"0*O`=*FKI7?[>Z]+95+
M)Z0T[_2#<(TLU'5-H\G$%(3=[862FJ#W(,CQSQ=7<,BPT/W2:O2[-GTT<:?2
M3;-^T?&[?DCK+1#,H.!8&()\1FY7*(NB<`T"-P'4\-M`A&S]C3(UF7!HF5>0
M"@1V3'C1'S:W)QOS#U8'I/E?COL#KP!WX_]-XG\5-@L+_I_+<V_^C\'_^"6C
M_R5$2WFWAB!-B)A,KD4LZS6%C3I@)3_&U@YJ<4A])4L$^8/$NX@(Q5)<O9G,
MQ'<*29$D-+L)=<2]ND_U,>'LJN,7JC:J\F=5>6;6Q#>JJLP\W_%/\[_WAUNO
M>\/FPRX`=^[_,_A_:X'_/)?G*_B?3T-\;9]D)#5Y$BAR1^PAW/+;K%,,R%T;
M;\8YH]<D-S8X]_@-]+U"3:/:BLA8#8N.;`IL54(C[`C%17A%'TU;?JG=\BVJ
MI0;GK9F9O_>(S/>9V/]5IS]H&7?P?SX_=?XKK&\N[/_G\MR;_[5,I84:97?H
MH;K?%:QPE&H_GC@_*:Y,>_P/X*7;]B95@JAJDUK+6.T489`RQ4!2U/"+)-[Q
M@Q#WZ1D%+$4&&LW!Q[8P*6!%X'4\U@6)Y\SR^#'Q.MZ29WR4%2'S@IF9->FH
MEFJ75+0FVR5]*VYN5PN:4X_K@D-!KU0-$DG9UIYP-J/T:*^$0`#2/M?F---Y
M\=J$`212146O9V1)&UTM?2*/>;P1L/F5U?ZDNC9U#VP:*R,R=S&'V70GWYAL
MJKMO)LBJ/XH)(FSTA)8XR[+6/VMX0>,UB[JQPDA#E$A/]NQGX:FPTOJ_,]8J
MI;!6]=@$1H4D$>/EK*ZY'8P&=74B8QX5)64NG;L1R$9JY8GD/#4FM>"ZP?5,
MZ,B5QIOR=;TB>4.2X[IZP]&[N`=4OV(E5,DR74*?S:"*W;BW$"U12^9577\'
MB=$D#;I`BM@>9CD(T]09PK(8+[CKMOV&>);5$A-.EO:]U[]_^I/>_[M7P9^=
MN>O_"OEI_9^S./_/Y7E`^9\F3RS\Q[`-^+XYZJ*O&%V?FK!K1P#%T:9,R4Q5
MXI^=E!0_^9$+BV3XJ;S?NUM_F"?-_X-6X/4";\[ZOXV\,W7^SZTO^'\>S[WY
M'S'MBX2AJ$6*<SE=M*.=ZB_E(S;8E^]B@8V<1=<>OW_<?=PT'[]^O/^XEK4N
MNQU=>_.J5CZH01ZT[`BV;=O)6>\L^(^#RGZI6V3#(JTQ&G8(0!(-OKT&6OV8
M?69^(RY>F*^%7B:,A&U=F*]$;53'"P05;5"8(P[!MZT;JA6Z,&1%[*;OMD]D
MFP=G:3U"LA35;K7\)+[]:"M/FO]C%##SO.D_U#)PE_W?1F[2_F_#R6\N^'\>
MS_WW_S=LD.0VFP*O[$`,`#8,8?_F2#ED$B8-*AZ).-XQDX#9)`'O+LY0$6BL
M8/A;0MW'<^MPU$L4BW-/<:'?),MRP6A)3NX9QU6,D/`,`^6'NVAH:,]2!?9$
M[U+$?ZN^/3BH'/QR5*X=(41/@(N)_MC%4),KG:#?4NBT$J.-'#8_"]1T+`?V
MJFVWE[,SHE;"JU'/_Q,_A:[?4>%74\D(UTV57S02%<%HL1_QYA-Q@CAD9*E2
MQ39%?6@G@&IM(Z]EOC2'%;CG-@PF'J^_(,>JMI1)G/'DGQ@U<.FW4H7I'!;U
MXG,XCI,=3B+5/8HY)L?I!"4C_MM8,;KGM&[?J[KVZI>T"Q'V./"A",Y&(6X3
M:/0H(S\GP)&4Q1K:C\LA2WKMU@D)H26>Y')HAZE^KN?0#Q>QYJ`]4>17%2!=
MAI=A>+GZE6<:>3$[&*DL4;B-@4^!T^NC,.1HWLGN3_3:<0_&HH8\@Z/!//?;
M?M1(S,D<E6=-0GI\:V3W2V$A;RV`LZCQEKF`58@]9P_G<<]8:9#"Q7#N.Z2)
M49*H253>;_OW')7U]*@\N6%4[H8`5.-P7^P_52?NX@CNTRB57[[]19CM,`'3
M%2/KS@"M3G0(ZJ*@C^1A1T<S"<'T$%ZV!@(2=''<WWH2.Q3EE3N72G3!(8NY
M2]3Y1B;*`1M0!H\TV6M%_$S@?N?>\"IIS(PVO[!%4&`@'8U7R6`95;;=42?T
M!QV&JPIL1"*P8"-QN_!N.[%5L/?EQ<4%_M_2A3UPPS,[[-NI"QY.2=>H:BCM
M1)QG^[4[;);\X&-@8^^=N">K.G4=_G(3-.Y/HFYA>J(1A'7946N7/YK0EWC2
M\I\,`CGG\Y^S.77^V]A:^'_,Y?D*_4]`4<,]-KYJC@8=O^$2)!WR-+LY$#H_
M:86ZEF0T.;5^8%;Y?_E(_H^BOYZ[P`X/;`!V)_]O3.*_%>#O!?_/XTGRO^1Q
M0H`/?-R3U=XL,%A5V.<PI^Q#P4@-&8[9VA^$]N"J&_1L.8&$Z9*GYEHAI^*U
M+CC_/_%)[_]^K]5_>%_0._E_*OYK(;>UP'^9R_-5^W^O24M$"#P>^`WA=5'9
M@8$^SU`_A"KBNCP9MOH+MO^/?M+\W^PW&#KE01>!N^]_)N/_K#OKB_U_+L_]
M^7_WK(^^QZSX(`S!KGN%IIQPOB>%<*VZ*TK^T!()3?'AP=Y[6A;Z/3@/H%(`
MC5TL+9/V&R$C:&E%T_3.*:()_"?R)B'_$1(SV.Z(T8W@OU<!W<!0C(!)9Q2=
MW3[%L.FW6E)?PA5')^YM+4,?Y'NHO(E(AJ]V7E8KNZ):WC_\K6P>[I7*5?/H
M]<X!T%)ZBG1&I:D0[H`BP6_N_U`KGF4'7OC@)_[T<P?_.]/^?P@`L>#_>3QI
M^5_>[-!^#NR+02.4\^M.:;]RL+]3V2M2T%H"Y$&=&.:Z(%2$9I\8G+QAB0YJ
MTY7_A:0B8321/U,^Q9H6E:[,%-'*C!`45-Y(65Q,>)/943ZJM$3N4EFPOBI,
M>Z2TQ827:6TM%R^MTVFY(O@%7-U49/6?Q4K.=K):#!1*'N-%!W.VO1YC5#2]
M^JBM<J<RD(ZVF-,XHI7H^L-A?T@J%!GM-":\7ZE6@;+$.T`-:-</0SA$#9N>
MU3BSI>&K!&^`;L=X!XTSM]?F("<*.Z`WZM:]88)PM;Q7WJF5BT[^J;/^Y$GN
M:5ZSV)'ZF\XQ9/(O]?_%\__"__?;/W+\!W!F]]QZXZ%=_^BY:_PWG,GS7WYS
MH?^9SY-:_T$(8LP%6II+7O`Q[`]LF!;:4?67&5]ZWL4)?M7B6VB94-,PK,ON
MP1&L>'N5`_F7ALO=_GN*^`+BVVDG$(8L\_29AOAQ'-W.$[K$F\&[1=0T;0N#
M\^G:DJ)\BF;HAOR%@95.-6V)KSK1[%KE4-';5#5.83T<"D/^5/G(JH"1[B;K
M@"#3JI18QQT1Z&#8+.M'=2&6_(^.TG[7_39RX!W\GW?R4_$_-A;GO_D\*?[O
M]-LXP8LZ3@?X8867(9RB4,QSBD\VK*<YR[&<@I:A-Z@HYCM_3I(O.EMYR]FT
M\AN0*,>I\I@*U@N0$YM]!.`KNHT&BC)^`**,EN&7F(B%2"E[-CBZHA_`L0NO
MEQD`RVV%WE"\$,%5M][O4+A:#+!:8@FHVX=CV17C;R$M^?G.!VH&\E?Q5!HJ
MOCLQ3QY?PIH0>89D=(PQ,"!LC$9PK@R6HW?P0ZX:NBZ>/\=HMM2/\IUYCV=6
MOLK^SIL:T&<+2#@U6\+`.LY*FWZG74N3C\JK6G'YV3*OAR-'#!R"Z>00C"-'
M?Z$;/`"2#!:''4WPQ@:%<YS=.0F$1C&1R=&U"?Q&>#>KYJK_!")IMEH8%O:3
M)YXX3_.P*!!.)7YU&XA^0\$X%+@/DL)W/`L-_L<TL;J.T+G:\%O!/3CB6-.-
M@:/++'G.DI=9\C.RX#O.T.N[H_"LV]S`.@0=S(32=%X\?5JXK6OB'A0<<(]?
MO_)[?G"&.PH'EKOG>!*8[C,Q%O^:-?5F3]^;)V0TL51M;IM97SY[O_>2MGB^
MX)'[/ZZZ]?[E"4&_?@O_W]OD__4I_6]A8X'_/Y]'[O^$_F]4FMMB<B8(QQ&P
M(#\U<WDSMRER3[;7X7_._XI^QQ<&88;N(=ZRRLB`COT6(89*>W+"MP@0U9)?
M\YX3:!KJ9TYBN/USI&&O6JOV*H@=%"/G(XCQ,E&$)C[LS;:]O72';=@7?%=@
MUK-`Z*X>A5;6;3T19><G8^,GW/W6*:.TZQ4O[!=V>_D?M8!)_O^F(,!WW?]L
MS8C_L;#_FL^3CO]!4LM$]+^+(0*=#B6.K433280Y&@5#DQ!6`S^D&$<SD1JC
M%%&XK;&F?4W0I;#?[Y@@F7=<#+B4K$CR"];CKE!++-^H#'`((;U$K;Q3W7TM
MJN4W>SN[J&Y(A%0B0VDV.4;@W<(4-=0:R-LOAGR]$FXH^$5!`90]$BL$AH)(
MOR+L8]0MZ=U]A#4HPFID@EP7NTX%".2*:Y0>V(:#%M%M71@%=0XQ*!LD(;?\
M^`U\-PK:TE+LI<3IH!7C:(U3Y__&V87;^W2.H>$Z?N/LP>]_;]O_-PL;D_>_
M^:V%_\]<GM3Y?R6R0N?9W!.GHP'9<4EWF*9[%<3[I;4Z&HCCE0\Y\^GOJ\=9
M_`I;][%S;#NY-7OY=)I:`CAB,$+K$$5X__6GR3U]7;<+.;&F/QO/HM0:>E&M
MEO^][W67IQQM=*A&?MTNK.DS*31;PGPCS(\8(J+7"A0Q./`['R-:&.7$<,1?
M0J?;HI6@$?B?@V96SUZ+8*V(DH?\]]E8E`]*0I8><-D;.:C$QMI6#EJ1F:R$
MKFOH*51OQ#UZO&(9QUG;.G8:77LN@HB56)X)A/$[Z/_7"]/Z_P7_S^=)\?^T
M`8B"UM9J>^7RFZ/*?KGH2'??UX>UHV)T#7QYJ6DO#P_WBN%PY&F:]/+#-ZS8
M)R\AL^$((\XMY&Z*N_3/.H41UG,Z!1)6""CLI&1$I4=;)7/0:RA97"#D,KEN
MP>I":I!3%/OYFM>$4P!.[C,YN<4%8BS#]AG=9P,QJGC+!<I+M#W2/<#W'IGY
M/-:T>/;@9=S)_^N3\G]^<W/A_S^7)\7_^^]KE:-RT7"8W8M.3M.TW=?EW5^!
M[XFQ]]^7=HYVBJ?*'=_@+*>*XW5#)M>9[???T^\9&91XSA09_,B0R5,@2*I\
MXD_X?=GU`M1-P&KBH4)8Z#4\>$C"T@ZB^4B?6"IX8=A&'&!.@N%-1`O&WK(L
M?6*I^>>L`HG[OV]Z_K^%_YVMW*3\#Z\6^K^Y/"G^IRU=]YK]H1ND;8YT[=?R
M>SB4T_6_%01G#-1]\M&[TAD:1(<.TK67.[4RZ?.&'&N=:1(RR*ER83W5,LQK
M&ZA><*&4'H,&)&[ZNC`LL6UI*+!<M-U\I$568+6B+J4474,X;WYEA?UNO7\E
MK+;K=^U.OQU@)6@)D(9E>'E/UTX27Z1^):#JZKZD'KDT?T!9Z'==@\9BO&@#
M.H"Q0UX8)+PD/>^IT;:AVHHY&?Y<F)^&([SA@IJ8=+<:6YVALB!!7`+3)<O8
M_LN>3=P6^>?_Y8C8A`TC-J<1%[!R47S%1*N`I`.M6OJ:9L'&L)1JUF0+D/@]
M6@")M'&RRD@S56%\<3;L]_Q/7UOINZIZ4R6A_M2*O]52U3XR=U$!TJ_CJ3NF
MS3$>*(-22?N3B5QJ;G,>U5.I''^#_^7ZWX))==9&-,WAU3?!?[M-_MLJ3.&_
MK2_PG^;SI-9_G+]OJWM)RU/T]0/1C6(SR/EA^]WVB58^*"&`B?7'H*WM'KX]
M.'I9_J5R`*=#^@%?BWB-K]5V?BO/L!Q+6%DA^`?]>(5SD.P%9#T^&#%ATU!T
M?S>X:,Z$\8Q4&2C`4JIB(J.L#QGJQLM$E*713.9G(?8#<A=E$R:>8E7)XO?8
M1JT555;2Q[LMXT.4UDQ48<WY7<LHDC^)F:W2EBXP])KY9]1ZE4$UEX1I;MT'
M]0TI+ZD&1J57\?4]5P;%_WZO>5+WVR=DX/8-_/]OY?_-*?[?7.`_S^>9NO^=
MF@GWN`!^A4[`[/A/%SIUB?>.-[R5@Q.*F:4;SKZNL9"&WCJ,NL%0L.S^<P[C
M(/UZPNX@\N9A1Q[1;&FE5T5C!=6V9UD98N$1HLA,(JBD8V[GQ+_8#M[T>V:W
M_ER/TW%X6SHEJG>EPY/*4?&4O)H-K"R<6?$^>\U0#8'E@S2\)N)?"1F92UR/
MQ?&SA`IYV9"U5VKIZV6IEM[0CT/=V-3AM+N%_WFR/([UPGN'>\53QK6BFD#F
M"Q`^.G$*!35]N*<3@`PIS"8Z(-413"CZ)E&#H_&W4L$@O\T<N_W^U]G<FHK_
MX&QM+LY_<WEN]_]3OF&:BOC(H,V)Z'JW7>'V+_G.-75+BV_N?SL;$/``>AXS
MI:G;V$B,P/"4QG4F"(<GL)",M:6N>WG2\7H(E4UUJJ$'$+/$C-K&=S#;]G'/
M;B\K:Y,L1S[?/RR]9:MUXYK)C:5=.4,Z76<XQ9BXTI"%DQY+*;*B&L6)X2VT
M@HW/X\\K*S&!-9$7V6RRH7".V'M;'N^<NWZ'XICVW_DU/LI&PX)1V3LC;[RB
M7(&,V/LG:UP?[&(<[L`]]P@,[Q[MTPU.D`0IC]HE4UQSDNW<]N98ZO.P")DX
M2BW+32>G#\FQY(Y96J)5LX74,;SE^+%I7,NN&6,K,?CE^'$@CGO<*I&H*4)Z
MR1^"YY?`N_9$CR<*_$IK!(+JPDF:GN31ZR^<Z0R:.AJZ1`CFL8\C',R8][?P
M:MRLZ([C.(SO._1$@NA$"@FBOY,)R&OM.(3/]%?R4^S*!U_C'\DDD2\;I(C^
MGDA`7G3\G4.P_JVA2*"FS1B1)*;:_0?&`UF`S=(I/Z(=(5$X>3"EE;AOLS?9
MB^@&[--8""ZTR3)JAV^KNR#C[`+7]CM>K+66'XP5K#G%/$`:62*:6`SR>-5E
M)/P<Z<8+I*(5@RED4W==8RW5*Q0/M=-O8V]TKS"8;Z]=).N<!+*>^I#2RD.F
MM@=GJ9#Q#/MNU\^^.'RG)]-+4Y/I$GD<9A0*;-T.SW@%O,ZHCV-8!0NX"BZA
MKTVT9$$BOYA[)OQ_%0W."'^OK5%"6KDXM7&-_XY-?8KK<=&@M=3`%&I9G%QH
M/ZME)FJ84%]NRA+3P\/MK!YPX2`=8@<D!X'[8'Y=DOG:+H&CPG6U7)KND<S7
M]\AP1#P)_X1!,67ZE.XSO<J(G-O475`4=]/$U`)^(D=@X-+^1T&=%Y,4IC"H
M'.@7V/5AT6VB`]<XDG+0PWDBDC5L\>6WE1)=4N?HBEK&=8E78.G(&V74EKYZ
M&6-*.*B32Y@LXSK>F&]<ON3ZI6J%UF:I53BY4O%2-6,>F*89"Q@!1>N2!.&+
M&FUYBV]<8Q>-<>O'+A(3-4&Z!"(3-4II^7'L78[\9XE:?SB\>D3UDR>TJ=I)
MABQ)5&^<#;!'-7A28DZI2_E3F,-$FX5Y*"WAXD4U_IJ],9]%[A^WY<44V70-
M25PID>O'C*KOES;$+MVYC[I4=ST>4)RKTE.]N0'?L[=5>M+JR<$X-;C3&"NQ
M.>#,G-2JF;DGIU"B08>_RC''CXVS;K\IUB[OZ%3%!L:*)\VU*@>UHYV]O81'
MNK5J+-]&)CM1&>K$G089EU=9QH5NE)5,"+MRR9$9#KR+&:FG:J.F=4*VC3_"
ML;N#F]Y4KE2_I3D)IR4R4J7GA[Y+/E$)GIK!3TM+[.83._KCNYO-<[#`SJRJ
MHDG-O:LJ6?Y]?R3.0$87_]?>L?:T<03[U?R*XV*I7(M?$)'442HY@`5*L!$V
M3:,FJAS?&4XUMN6S(43AO_2G=N>QKWO89T,>JO`'L.]V9V=G=N>QCQE.7X0Q
M!4;!#03LOH9;6N-1V:E[!K)QQAP/,!($YOZ!-+P!=\31J&\[$_),8.XS)Q;P
M7S>6WL^+=5CR#L-&4"`&(9;&0]\1WVYE]Z_H[F]OBA%H;L+9I1%#`3RE+`M<
MZ3E$%ZVYE-8[L/PEU">&;0@0B7$?$AOX=03@]&AX2Q?N+Z/''[:!(<:K1-<_
M</OH14DD##X!!BVAY=JO-Q5MH>S=AJW3(,#M`RBT"')%)[490`=5MLB;R:OG
M`);M/[5/`8ET39=;8Q&I<NLM14Q)<PQ]C-B'-`PQ1`C*L^3$Z0JK>DCV%.D/
M#.P\&]<=TA!2(,D(TF2,&&,\@?CA"#Q(WYBL=)3\YZC"$4GX?PW6/+*X((^:
M&UR!S]6U_7@1%\VYD)0Y!V&T!,^:PO>KXTDK#X47+U#+%3`"3$Z&H0N;QC#I
MWMZ39RKL3%5__7$Y9Z!H(/ZM^4<2WC.X@6[MCIO-!>1MAR*>.VP\`E/9[=E)
M=-:-ONC`/9PTPE!?*2]WO"\7[G=A&W3!"-'6<V"ST>A0G'R]<'@/XC6.WRPE
MG8XM):FC5U127OY`I#O$=:$&1LI:0,-?DN*#%+#06%-1=R)<4*#6/\$M7#]W
M,.B=H%G-A*DM"&FZGHZC*(0EX-XTJ%/LJ6T*6+4M[1KP@0%'`Q`C%42]?DS3
M"=OCKCT:WJ)Q$4UZ-R/!GV!T'0K?$:)"DET$YJ!<F@3[0`7\$^;(^*(<-R>$
M/?'D7QU27Y@\\\&`C(QK2#0D""F<;`Z"M9:%@6#ZPS"`10(#6LSBR"JVNC,=
M.0#+(5@.P<HV,\`7XZRE5^2;A7O/]V)KZ"?==Z>'+]U/XL6&8>3&*HK7?^\]
M3:_:N_+%JPUI\DFNGG`ND]GM!*/H0&%7H8:3609&ZTUFX6SN!W9LM'1_$)P$
ME0K82ME;=AI62F^V_6%X4Z)3E:X7C]T65*LE5=;Y.`^'?@GL[Y%PF(808V<.
M6T<]7_@?=E;9I'$K46NUNZGH\6C%(^]XJQ%:9-3\8!*,_&#4#X-HTU5LY)2G
M?5],!$6Z`3^H0!:0-X!AP_=#7#(J$9W+8"!:O.I/\E4"407E460M+)I&@7,T
M(,#UPHUL3,V$N_FR[V`KP]/]@[/VB8S<BV/Z8@YN7D\VY/1]X1J-RYH4<XL6
M]IH10Y^`-'3V9]/AK_OH-PE?B7S(3S-GMRJ7W*!=X-$TP,"?&,2/>+2ISV/O
M8NH6+B*^P9(0B!7*.XNK=1A)PUZM`^:XJ?=0V6,VDO"6EY3$IOBT`5[[-)._
M<*Z>Q(11L..@=88U4#5&+]1FC^H`;ZK`@4+&10&&G?QR2@$`N-K^;UG'>/TZ
M&\P_+=W_W]U[&L__4=NI/<9_^B8?Z_ZWVB"O\G9X9"W'5+U*Y<+Q4LX)F&=(
M-N">5J?;.#E]:2=_Y-R/QMH_BA(^EIT_.]R]4\,9R8Z@,/YY(M>C0#12/%&4
M<WQGF\MP"."HSK];S4[A!,[<M45?J4)IAK=):[]!**SG$"^K'LM>9*2]PF/<
MGL2@B>&&)4#7Y<=_O&K_Z72:XKO=5!D$=C1P,J!B;0W+W'.9VX3/(,!\90IP
MC97Z=V[_S$A19>>G4ATQ`S'3`#)ZAK^I34I-6K'SC1F5XQG'7*+)_E'[;0LZ
M1BO=SYX]<XH:H$>%3EX+>,@4=;I4EV%68$$K`R&>Q1*VASKF;<:NOL,H74*C
M&U6*ZGNI%'SJ#\%B@A-J#L&BXY[X]>S@N-FL`48Z49D5`]M.5*8!8THV"W=5
MSM.0=W)#+I5$#_NPLDT)@4KCH;#?2K-+88P5=Z$UJP5L`H[8X3$_"/YRZ>3E
MF*<J'ZU:65?MYJG*>+8.W[XY[G0QA^.6/`68>WP9DU,)#IEQ,CZ-L:@Y8XU,
M<FB^(YCD*4""[F)%V.W`W[`JS,<`TZ"T,\"TXW#:V8#.LR"=)T"=+X/%0SD)
MJ]L04\XUQQ[`X^(+.HES-:63-(>-3N*#."`ZR(H'0F=CX:A`21PX[T?X$'@L
MGQWQLT'OXS3LRZ=-]R'S`)K]ITR`$.&CXQRWK'F,*0'U@'T_>C\21?$PJY$S
M$'[SJT0^0>23)F^1!8%\TY:<5'0KDNA4Y+M+7E#*$MBB!ZGB.GTFF2:&9UDK
M-:]<5*9(61AYY8O/.Z[6^"ER>]7V#$6+`[*XA<84&)2E_N<!A8U%%L1EG<)B
MH;Q;5]2M)^64@%/(Y1!R.:BTBK!33<_CXV*QT"O<4]H5EHNY%"02HJZPAHR#
MD6-`(,DFAA!4AA^+48A+M,)R46:-O7N+,QNG-)&&)0IYY%FZ)%MY5CZ4O`/J
MIPLXUS$$F[9&X7+>RNZ,4>L>/DT,RGH6I]0]JYJ=1DRL,[BN>-KH=-ZVSP[,
MI4-\`2)26XYXOS)F,O:N+P4+*&.<P%&U?H?&J1!^]JW^>'N_)UQ3;&5R4RH6
MR[2F1K;\7K6ZO.@31GI=]'>-D+)\^W=AD^D=Q@!>2U!]V/S""'UQAF&B1Y[L
MPO&1F6(*8"2H='/`4%LQ2;58B;F&EG0M:99?9<(R.>EG5P:U5"7K2J"**<5)
M@V!6@9I<#IG\.X9-DG0%$X":PZSI?':_U3W*W[JL3TAH(V1=1"I%0B#E+!F>
M',>WB"P=-K5:`PF<(DK\G+Z4>9+:!&OPRZB*3"ODXEJFM\BN>1Z293J`)@.1
M@V2LKXB*S<?<C%P"KL*>0R8[Z37A3@R-<Y1I3"]!,FWD$CRL.5$8;%'<N;J@
M!WWS/!)$*17F%`VF!$-)VB_29D'U3C9+I-6^],(L(_,N(98X*>XBR20-,:45
M!OY\$L1SP<=E,.#PZK#9/CO,;\%[?-'W957?Y8.1P[DTBEO<<FD*A@;=(UX,
MD,<-WRG>VBKRE6)HBN4Y.C"J/3U]&TV\<)P?=_O^8I$O5UL*JK#*(&'69(X)
MR3H:%92U`Y\%/NB`??(.4$I\#`0=`VG1$EOX%>8;D&^PS_KV*"L]LD9&XT$X
LD^C&4&C"G1O'Y=55N<-)W-I,&N7Q,?F]-P@>/X^?Q\__]O,?_5$.:0`8`0``
`
end
