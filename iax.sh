#!/bin/bash
clear
# Version 2.5
# 2012.05.04
# Perform Mtzdump, SCALA, Molrep, Refmac
# The fisrt workable version.
# Now work at any directory.
# Now work with other datasets, but may not work with multi-subunits.

#======================= Welcome ======================

	echo '===================================== Welcome ======================================'
	echo
	echo "                                 iAutoXtal Ver 2.5"
	echo "       Perform Mtzdump, SCALA, Molrep, Refmac automatically, save your time."
	echo "                                     2012.05.04"
	echo "                                  Dr. Xiaopeng Hu"
	echo "		      Sun Yet-sen University, Guangdong, Guangzhou, China"
        echo
        echo "===================================================================================="
        echo

	echo "Your input files should be named as work.mtz and model.pdb.Work.mtz is the unmerged "
        echo "diffraction data and model.pdb is a suitable model for MR."
	echo
  	echo "Are you ready to run iAutoXtal? (yes/no):"
  	echo "Currently [yes]"
  	read response;
  	if test "$response" = "no" -o "$response" = "n" -o "$response" = "N"; then :
		echo
		echo
    		echo "Please prepare your files well,I will stop at here!"
		echo "Bye!!"
		exit 
  	else
		echo
		echo
    		echo "OK, your wish is my command......"
		echo "You will find your results named refmac2.mtz and refmac2.pdb, if all runs well"
		echo
		echo "===================================================================================="
  	fi


#======================= End of Welcome ======================




#=======================================  Constants ============================================

#general
GoodEnough=1
EMAX="EXCLUDE_RESOLUTION_MAX    "
EMIN="EXCLUDE_RESOLUTION_MIN    "

#For SCALA
RunTime=0 # counter of SCALA running
Rmerge_BAD=0.6 # Rmerge should be less than 0.6

#For Molrep
Const1=3 # good
Const2=2 # acceptable
Const3=1 # bad

# For Refmac5
RfreeSTD=0.3500 #good Rfree and run restrained refine!
RfreeBAD=0.5000 #bad Rfree and stop refine!
#=======================================  END of Constants =====================================


#======================================= Clean old run files ===================================

# remove files of last run.
 
rm -f auto*  
rm -f *.log  
rm -f *molrep* 
rm -f *refmac* 
rm -f -r CCP4_DATABASE_AUTO

#======================================= End of Clean old run files ============================



#==================================  For Files ===================================

 WorkSite=`pwd` #get current working directory
 DefSite=$WorkSite"/CCP4_DATABASE_AUTO"

#copy all def to working directory
 cp -r /home/acta/work/auto/CCP4_DATABASE CCP4_DATABASE_AUTO #copy all def files to working directory
 cd ./CCP4_DATABASE_AUTO 
 chmod 777 *.*
 cd ..


# def file for SCALA
  OldDir="#CCP4I PROJECT auto /home/acta/work/auto/CCP4_DATABASE"
  NewDir="#CCP4I PROJECT auto "$WorkSite"/CCP4_DATABASE_AUTO"
  
#modify database.def with working directore  
  sed -i "s@$OldDir@$NewDir@" $DefSite/database.def
 

#==================================  END of files ==================================



#================ Run MTZDUMP, get Ressolution Range of input MTZ file =============

	echo
	echo
	echo "I am running MTZDump, Please wait...."
	mtzdmp $WorkSite/work.mtz >>mtztemp.log
 

if grep "MTZDUMP:   Normal termination of mtzdump" mtztemp.log>/dev/null;then
	echo
	echo "======================== MTZDUMP completed successfully! ==========================="
	echo
	
	TEMP=`grep -A2 "Resolution Range" mtztemp.log|tail -1`
	#echo $TEMP
	ResMin=`echo ${TEMP:33:6}`
	ResMax=`echo ${TEMP:47:5}`
	#echo $ResMax
	#echo $ResMin
else
	echo "Can't finish MTZDump, Please check your MTZ file!"
	echo "We stop at here now."
	echo "Bye!!"
	exit 
fi

#=======================================  END of MTZDUMP ======================================



#======================================= Modify SCALA def files =====================================

#Set Resolution Range

  TempResMax=$EMAX$ResMax
  TempResMin=$EMIN$ResMin
  #echo $ResMax
  #echo $ResMin

  OldResMax=`grep "EXCLUDE_RESOLUTION_MAX" $WorkSite/CCP4_DATABASE_AUTO/1_scala.def`
  OldResMin=`grep "EXCLUDE_RESOLUTION_MIN" $WorkSite/CCP4_DATABASE_AUTO/1_scala.def`
  sed -i "s/$OldResMax/$TempResMax/" ./CCP4_DATABASE_AUTO/1_scala.def
  sed -i "s/$OldResMin/$TempResMin/" ./CCP4_DATABASE_AUTO/1_scala.def

#====================================  END of  Modify def files ==================================




#=============================== Run SCALA until Rmerge is less than 0.6 =========================


while [ $GoodEnough -gt 0 ]
do

# count the run of SCALA 
let Runtime="$Runtime+1"

# Remove files of last run
rm -f auto*  
rm -f *.log  



#==== Get current max resolution =====
#=== OldResMax is: EXCLUDE_RESOLUTION_MAX    2.000 ====
OldResMax=`grep "EXCLUDE_RESOLUTION_MAX" ./CCP4_DATABASE_AUTO/1_scala.def`
#=== CurrResMax is 2.000 ====
CurrResMax=`echo ${OldResMax:25:31}`

#==== Start run SCALA =====
echo "===================================================================================="
echo "I am running SCALA, Please wait...."
ccp4ish -r ./CCP4_DATABASE_AUTO/1_scala.def>>temp.log



if grep "#CCP4I MESSAGE Task completed successfully" ./1_scala.log >/dev/null;then
	echo
	echo "SCALA completed successfully! "
else
	echo "Can't finish SCALA, Please check your MTZ file!"
	echo "We stop at here now."
	echo "Bye!!"
	exit 
fi


# Output summary data to Summary.scala


  echo "============================= Summary data of SCALA ==========================="$Runtime>>Summary.scala
  grep -A32  "Overall  InnerShell  OuterShell" ./1_scala.log>>Summary.scala

  #==== Get Rmerge of the just finished run =====
  temp=`grep "Rmerge            " ./1_scala.log`
  rmerge=`echo ${temp:60:70}`
  #echo $rmerge

  #==== If current Rmerge good enough?
  GoodEnough=`expr $rmerge \> $Rmerge_BAD`

if [ $GoodEnough -gt 0 ];then
  # Rmerge is not good....., set higher resolution cut, 0.1A for each time.

  #=== TempResMax is 2.100 ====
  TempResMax=`echo $CurrResMax+0.1| bc`

  #=== NewResMax is: EXCLUDE_RESOLUTION_MAX    2.100 ====
  NewResMax=$EMAX$TempResMax
  echo "Current resolution is :"$CurrResMax
  echo "Current Rmerge is :"$rmerge
  echo "Rmerge is NOT good enough, now set SCALA at higher resolution."
  echo 

#==== Write new resolution cut in to def file ====

  sed -i "s/$OldResMax/$NewResMax/" ./CCP4_DATABASE_AUTO/1_scala.def

else
  echo "Current resolution is :"$CurrResMax
  echo "Current Rmerge is :"$rmerge
  echo "Rmerge is good enough! Stop SCALA."
  echo
  echo
  echo "============================ Summary data of SCALA =========================="
  grep -A31  "Overall  InnerShell  OuterShell" ./1_scala.log
  echo
  echo
  echo "For Summary data of all SCALA running, please check Summary.scala."
  
fi

done

#==========================================  END of SCALA ==========================================





#====================================  Modify Molrep def files ==================================


#def file for MolRep, e.g, space group
# get spcae group number from log file
temp=`grep "Spacegroup: " 1_scala.log|tail -1`

# number of space group
SpaceGroupNumber=`echo ${temp:29:4}`


temp=`grep -w "^$SpaceGroupNumber"  /usr/local/ccp4/ccp4-6.2.0/lib/data/mysymop.lib`


# name of space group
SpaceGroup_Full=`echo ${temp#*X}`
SpaceGroup_Full=`echo ${SpaceGroup_Full%X*}`

SpaceGroup=`echo ${temp#*W}`
SpaceGroup=`echo ${SpaceGroup%W*}`



# def file for MolRep
Old_SpaceGroup_Full=`grep "FILE_SPACE_GROUP          " ./CCP4_DATABASE_AUTO/2_molrep.def`
New_SpaceGroup_Full="FILE_SPACE_GROUP          ""\""$SpaceGroup_Full"\""
sed -i "s/$Old_SpaceGroup_Full/$New_SpaceGroup_Full/" ./CCP4_DATABASE_AUTO/2_molrep.def

Old_SpaceGroupNumber=`grep "SPACE_GROUP_NUMBER        " ./CCP4_DATABASE_AUTO/2_molrep.def`
New_SpaceGroupNumber="SPACE_GROUP_NUMBER        "$SpaceGroupNumber
sed -i "s/$Old_SpaceGroupNumber/$New_SpaceGroupNumber/" ./CCP4_DATABASE_AUTO/2_molrep.def

Old_SpaceGroup=`grep "TEST_SPACE_GROUP          " ./CCP4_DATABASE_AUTO/2_molrep.def`
New_SpaceGroup="TEST_SPACE_GROUP          "$SpaceGroup
sed -i "s/$Old_SpaceGroup/$New_SpaceGroup/" ./CCP4_DATABASE_AUTO/2_molrep.def


Old_LaueGroup=`grep "LAUE_SPGP_LIST            " ./CCP4_DATABASE_AUTO/2_molrep.def`
New_LaueGroup="LAUE_SPGP_LIST            ""\""$SpaceGroup"\""
sed -i "s/$Old_LaueGroup/$New_LaueGroup/" ./CCP4_DATABASE_AUTO/2_molrep.def

#====================================  END of  Modify Molrep def files ==================================


#==========================================  Run MolRep  ========================================== 


echo
echo "===================================================================================="
echo "I am running MolRep, Please wait...."
echo

ccp4ish -r ./CCP4_DATABASE_AUTO/2_molrep.def>>temp.log


if grep "#CCP4I MESSAGE Task completed successfully" 2_molrep.log>/dev/null;then
	echo
	echo "=========================== MolRep completed successfully! =========================="
	echo
else
	echo "Can't finish MolRep, Please check your MTZ and model file!"
	echo "We stop at here now."
	echo "Bye!!"
	exit 
fi


#==== Get Contrast of the just finished run =====
temp=`grep "Contrast " 2_molrep.log`
Contrast=`echo ${temp:15:5}`
#echo $Contrast

# Get interger of Contrast
TempContrast=`echo ${Contrast%.*}`
 


if [ $TempContrast -gt $Const1 ];then
	# Contrast>3
	echo "Contrast is "$Contrast", MolRep has found a solution!"
else
	GoodEnough=`expr $TempContrast \> $Const2`
	if [ $GoodEnough -gt 0 ];then
		# Contrast>2
		echo "Contrast is "$Contrast", MolRep has found a plausible solution!"
       	else
	# Contrast<2
		echo "Contrast is "$Contrast", MolRep could not found a solution!"
		echo "Please check your MTZ and model files!"
		echo "We stop at here now."
		echo "Bye!!"
		exit 
        fi
fi

echo

#==========================================  END of MolRep  ==========================================




#========================================== For Refmac5 Rigid Body Refinement ==========================================


echo "===================================================================================="
echo "I am running Refmac5 Rigid Body Refinement, Please wait....."
echo

ccp4ish -r ./CCP4_DATABASE_AUTO/3_refmac5.def>>temp.log


if grep "#CCP4I MESSAGE Task completed successfully" 3_refmac5.log>/dev/null;then
	echo
	echo 
	echo "=============== Refmac5 Rigid Body Refinement completed successfully!= =============="
	echo
else
	echo "Can't finish Refmac, Please check your MTZ and model files!"
	echo "We stop at here now."
	echo "Bye!!"
	exit 
fi

echo "===================================================================================="
echo "================== Final results of Refmac5 Rigid Body Refinement =================="
grep -A2 "                     Initial    Final" 3_refmac5.log
echo

#==== Get R factor of the just finished run =====
	tempR=`grep "           R factor" 3_refmac5.log`
	Rfactor=`echo ${tempR:32:6}`
	
	#echo $Rfactor

	tempRfree=`grep "             R free" 3_refmac5.log`
	Rfree=`echo ${tempRfree:32:6}`


	#echo $Rfree

# Compare Rfree with 0.5
 
	GoodEnough=`expr $Rfree \> $RfreeBAD`
	#echo $GoodEnough

	if [ $GoodEnough -gt 0 ];then
	# Rfree > 0.5
		echo "Rfree is too high, something is wrong!! Please check your model and setting! "
		echo "We will stop at here!"
		echo "I am sorry. Bye!!"
		echo
		echo
		exit 
	fi


	
	GoodEnough=`expr $Rfree \> $RfreeSTD`
	if  [ $GoodEnough -lt 0 ];then
		echo
		echo
		echo "Rfree is OK, I will run Refmac5 Restrained Refinement now. "
		echo "Make sure you don't have any unknown ligand/residual in your model."
		echo "Otherwise Refmac would not work."
		echo 
	else
		echo "Rfree is accpetable, you may need to modify your model first"
		echo "before running Refmac5 Restrained Refinement."
		echo
  		echo "Do you still want to run Refmac5 Restrained Refinement anyway? (yes/no):"
  		echo " Currently [yes]"
  		read response;
  		if test "$response" = "no" -o "$response" = "n" -o "$response" = "N"; then :
			echo
			echo
    			echo "We will stop at here!"
			echo "Bye!!"
			exit 
  		else
			echo
			echo
    			echo "OK, your wish is my command, I will run Refmac5 Restrained Refinement now."
			echo "Make sure you don't have unknown ligand/residual in your model."
			echo "Otherwise Refmac would not work."
  		fi
	fi

echo
 
#==================================  END of Refmac5 Rigid Body Refinement ==================================



######################  For Refmac5 Restrained Refinement  ###############################
echo
echo "===================================================================================="
echo "I am running Refmac5 Restrained Refinement, Please wait....."
echo

ccp4ish -r ./CCP4_DATABASE_AUTO/4_refmac5.def>>temp.log


if grep "#CCP4I MESSAGE Task completed successfully" 4_refmac5.log>/dev/null;then
	echo
	echo "#### Refmac5 Restrained Refinement completed successfully! ####"
	echo
else
	echo "Can't finish Refmac, Please check your MTZ and model files!"
	echo "We stop at here now."
	echo "Bye!!"
	exit 
fi


echo "===================================================================================="
echo "================== Final results of Refmac5 Restrained Refinement =================="
grep -A5 "                     Initial    Final" 4_refmac5.log
echo

#==== Get R factor of the just finished run =====

	tempRfree=`grep "             R free" 4_refmac5.log`
	RfreeFinal=`echo ${tempRfree:32:6}`
	RfreeStart=`echo ${tempRfree:23:6}`




# Compare Rfree with 0.5
 
	GoodEnough=`expr $RfreeFinal \> $RfreeStart`
	#echo $GoodEnough

	if [ $GoodEnough -gt 0 ];then
	# Rfree > 0.5
		echo "Rfree goes up, something is wrong!! Please check your model and setting! "
		echo "We will stop at here!"
		echo "I am sorry. Bye!!"
		echo
		echo
		exit 
	else

		echo
		echo
		echo "Rfree goes down, Refmac5 Restrained Refinement works! "
		echo "THANK YOU for using iAutoXtal."
    		echo "Bye!!"
		echo
		echo
		exit 

	fi

echo
 
#==================================  END of Refmac5 Restrained Refinement ==================================

