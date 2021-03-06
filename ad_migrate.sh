##
## This is a program designed to assist in migrating a non- AD user
## on a mac to their AD user. For this to work, we are assuming that
## the machine is already properly named and bound to the AD domain
##
## Created by James Nielsen
##

#!/bin/bash

clear

echo "AD migration assistant v1.4"
echo
echo "This script was designed to assist in migrating a non-AD user"
echo "to AD while keeping their Desktop background, files, and most"
echo "of their preferences."
echo

# Change text color to red
echo "$(tput setaf 1)Warning: Do not run this script while the user you're migrating"
echo "is still logged in. Log them out first and run this script as"
echo "an administrator on their machine.$(tput sgr0)"
echo
echo
echo "Make sure the machine has a wired connection on the school networks"
echo
echo
echo "$(tput setaf 2)Exit this script at any time by hitting $(tput setaf 5)CTRL+C$(tput sgr0)"
echo
echo "Created by courtesy of Team 'FARK"

# Pause to continue
read -n 1 -p "$(tput setaf 4)Press any key to continue...$(tput sgr0)"

clear

# Turn off wireless
echo "Turning off wireless. Please enter in your administrative password"
sudo networksetup -setairportpower en1 off
sleep 4
echo "Done"

# Check if AD servers are available
if ping -c 2 -q ad1.alpine.local &> /dev/null
then
	echo "There 1"
	exit;
else
	if ping -c 2 -q ad2.alpine.local &> /dev/null
	then
		echo "There 2"
		exit;
	else
		if ping -c 2 -q ad3.alpine.local &> /dev/null
		then
			echo "There 3"
			exit;
		else
			echo "Not there"
			exit;
		fi
	fi
fi
exit


# Check if the machine is bound to AD
echo "Checking what domain the machine is bound to for Active Directory"

ADTEST=$(dsconfigad -show | awk '/Active Directory Domain/ {print $5}')
if [ $ADTEST = "alpine.local" ]
then
    echo "You are bound to $(tput setaf 2)alpine.local$(tput sgr0). Moving on."
else
    echo "You are $(tput setaf 1)NOT$(tput sgr0) bound to $(tput setaf 2)alpine.local$(tput sgr0)"
    echo "Please bind the machine before running this script."
    exit
fi

i_am=$(whoami)

# Create an array from the list of users in dscl- excluding users
# with "_", daemon, nobody, and root
user_list=($(dscl . -list /Users | grep -v -e "\_" -e daemon -e nobody -e root -e $i_am))

# Tech selection of users
select old_user in "${user_list[@]}"
do
	test -n "$old_user" && break;
	echo ">>> Invalid Selection. Type the number associated with your user."
done
#echo $old_user

# List selected user's Home Directory and store as old_user_hd
old_user_hd="$(sudo dscl . -read /Users/$old_user | awk '/NFSHomeDirectory/ {print $2}')"
#echo "$old_user_hd"

# Check if the value pulled from dscl is null or not
if [ -z "$old_user_hd" ];
then
# If null, then grab the second line after
	old_user_hd="$(sudo dscl . -read /Users/$old_user | grep -e "/Users/$old_user_hd")"
# Now, trim the excess leading space
	old_user_hd="$(echo "$old_user_hd" | sed -e 's/^[[:space:]]*//')"
#	echo "$old_user_hd"
fi

echo "Now please enter in the AD username of that user: "
read new_user

# Remove the user using dscl
echo "Removing old user from local directory"
sudo dscl . -delete /Users/${old_user%/}
sleep 2
echo "Done"

# Rename the old username to the new AD username
echo "Rename their home folder to match the AD username"
sudo mv "$old_user_hd" /Users/$new_user
sleep 2
echo "Done"

# Set ownership of the entire folder to the new user
echo "Setting ownership of their home folder"
echo "This may take a little while- $(tput setaf 2)Please, be patient$(tput sgr0)"
sudo chown -R $new_user:staff /Users/$new_user
sleep 2
echo "Done"

# Remove Keychain items
echo "Removing Keychain items"
sudo rm -rf /Users/$new_user/Library/Keychains/*
sudo rm -rf /Users/$new_user/Library/Keychains/.fl*
sleep 2
echo "Done"

# Remove dropbox file
echo "Removing Dropbox associated file"
sudo rm -rf /Users/$new_user/.dropbox
sleep 2
echo "Done"

# Adding new_user to admin group
echo "Adding user to admin goup"
sudo dscl . -append /Groups/admin GroupMembership $new_user
sleep 2
echo "Done"

# Turn wireless back on
sudo networksetup -setairportpower en1 on

# Finished
echo "User migrated!"

#rm -rf /Users/Shared/ad_migrate.*
