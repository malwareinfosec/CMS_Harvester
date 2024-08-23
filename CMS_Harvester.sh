#!/bin/bash

# Get the absolute path of the script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change the working directory to the script's directory
cd "$script_dir"

# Create a data directory if it does not already exist
if ! [ -d "data" ]; then mkdir data;fi

# Count number of hostnames from user supplied list
total_hostnames=$(cat list.txt | wc -l)

# Set variables to default value
current_counter=0 # This is the current counter used to track progress
skip_lines=0 # This variable is used to skip lines from list of hostanmes
# If user entered a number (n), we will skip n lines
if [ "$#" -gt 0 ]; then skip_lines="$1";fi

# User-Agent string used by curl command
user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36"

# Array of different CMS types
CMS=("WordPress" "WooCommerce" "Magento" "Joomla" "PrestaShop" "Drupal" "OpenCart" "Shopify" "BigCommerce" "Volusion")

# Detection rules set as arrays for each CMS
WordPress=("\/wp-content\/")
WooCommerce=("\.woocommerce" "<meta name=\"generator\"\scontent=\"WooCommerce")
Magento=("\/skin\/frontend\/" "text\/x-magento-init" "Mage\.Cookies\.path" "magentoCart\-")
Joomla=("<meta\sname=\"generator\"\scontent=\"Joomla!" "\/css\/template\.css")
PrestaShop=("var\sprestashop\s=\s\{" "meta\sname=\"generator\"\scontent=\"PrestaShop")
Drupal=("enerator\"\scontent=\"Drupal")
OpenCart=("Powered\sBy\s<a\shref=\"http:\/\/www.opencart.com" "\/css\/opencart\.css" "PayPal\sto\sdonate@opencart.com")
Shopify=("Shopify\.theme(\.handle|\.style)?\s=")
BigCommerce=("cdn11.bigcommerce.com")
Volusion=("Built\sWith\sVolusion.<\/a>" "volusion.cart.itemCount\(quantityTotal\);")

# Loop through list of hostnames
echo "Launching CMS Harvester..."
for hostname in $(cat list.txt);do
	# Increment counter
	((current_counter++))
	# Used to skip lines (resuming harvest)
	if ((current_counter > skip_lines)); then
	    cms_found="false"
	    unknown="true"
	    hostname=$(echo "$hostname" | tr -d '\r')
	    # Get source code for current hostname
	    source_code=$(curl -sSf --connect-timeout 10 --max-time 10 --user-agent "$user_agent" -L "$hostname" | tr -d '\0')	    
	    # If source code is not empty, check for CMS
	    if [ -n "$source_code" ];then
	    	# Loop through list of CMS	   	
			for cms in "${CMS[@]}"; do
				# Loop through list of regexes for each CMS
				for item in "${!cms[@]}"; do
			    	if [[ $(echo "$source_code" | grep -E -i -o "${cms[$item]}" | wc -l) -ge 1 ]]; then
			      		cms_found="true"
			      		break  # Exit the inner loop if a match is found
			    	fi
			  	done
			 	# Add the hostname to a text file for the CMS that was found
			 	if [[ $cms_found == "true" ]]; then
    				echo "$hostname" >> "./data/${cms}.txt"
    				cms_found="false"
    				unknown="false"
  				fi
			done
			# Add hostname to a list of unknown CMS
			if [[ $unknown == "true" ]]; then echo "$hostname" >> "./data/unknown.txt";fi
	    else
	    	# We could not get the source code for the current hostanme
	    	echo "$hostname" >> "./data/down.txt"
	    fi # End source code check
	    clear
	    # Get the current percentage for the harvest
	    percentage=$(echo "scale=2; ($current_counter * 100) / $total_hostnames" | bc)
	    # Display stats on the CLI
	    echo "## CMS Harvester ##"
	    printf " -> Checked $current_counter/$total_hostnames hostnames (%.2f%%)\n" "$percentage"
	    for item in "${CMS[@]}";do
	    	if [ -f "./data/$item.txt" ];then echo " * $(cat "./data/$item.txt" | wc -l) $item sites found";fi
	    done
		echo ""
		if [ -f "./data/unknown.txt" ];then echo " * Unknown: $(cat "./data/unknown.txt" | wc -l)";fi
	    if [ -f "./data/down.txt" ];then echo " * Down: $(cat "./data/down.txt" | wc -l)";fi
	fi
done
