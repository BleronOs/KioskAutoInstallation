#!/bin/bash

########################
#   Set Data
########################

sudo apt install -y whiptail

# Function to prompt for input using whiptail
prompt_for_input() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3
    
    value=$(whiptail --nocancel --inputbox "$prompt_message" 10 60 "$default_value" --title "Input Required" 3>&1 1>&2 2>&3)
    echo "$value"
}

# Function to validate IP address
validate_ip_address() {
    local ip=$1
    local valid_ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    # Check if it matches the IP format
    if [[ $ip =~ $valid_ip_regex ]]; then
        # Check if each segment is between 0 and 255
        IFS='.' read -r -a segments <<< "$ip"
        for segment in "${segments[@]}"; do
            if (( segment < 0 || segment > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to collect data
collect_data() {
    IP_ADDRESS=""
    USERNAME=""
    PASSWORD=""
    FIRST_VALIDATION=""
    SECOND_VALIDATION=""
    THIRD_VALIDATION=""

    # Define the variables and their prompts in the correct order
    vars=("IP_ADDRESS" "USERNAME" "PASSWORD" "FIRST_VALIDATION" "SECOND_VALIDATION" "THIRD_VALIDATION")
    prompts=(
        "Enter the IP address:"
        "Enter the username:"
        "Enter the password:"
        "Enter the first validation value:"
        "Enter the second validation value:"
        "Enter the third validation value:"
    )

    # Iterate through the variables in order and prompt for input
    for i in "${!vars[@]}"; do
        var_name=${vars[$i]}
        prompt_message=${prompts[$i]}
        default_value=""

        while true; do
            read_value=$(prompt_for_input "$var_name" "$prompt_message" "$default_value")
            
            # Validate IP address if the variable is IP_ADDRESS
            if [[ $var_name == "IP_ADDRESS" ]]; then
                if validate_ip_address "$read_value"; then
                    break
                else
                    whiptail --msgbox "Invalid IP address format. Please enter a valid IPv4 address." 10 40 --title "Invalid Input"
                fi
            else
                break
            fi
        done

        eval "$var_name=\"$read_value\""
    done
}

# Main script loop
while true; do
    collect_data
    CHOICE=$(whiptail --nocancel --title "Kiosk Setup" --menu "Choose the orientation for the kiosk:" 10 60 2 \
    "1" "Horizontal" \
    "2" "Vertical" 3>&1 1>&2 2>&3)

    # Determine the type of kiosk based on the choice
    if [ "$CHOICE" -eq 1 ]; then
        KIOSK_TYPE="Horizontal"
    elif [ "$CHOICE" -eq 2 ]; then
        KIOSK_TYPE="Vertical"
    else
        KIOSK_TYPE="Unknown"
    fi

    # Display the filled values and ask for confirmation
    if whiptail --yesno "Data Collected:
IP Address: $IP_ADDRESS
Username: $USERNAME
Password: $PASSWORD
First Validation: $FIRST_VALIDATION
Second Validation: $SECOND_VALIDATION
Third Validation: $THIRD_VALIDATION
Type of Kiosk: $KIOSK_TYPE

Is this information correct?" 20 60 --title "Confirm Data"; then
        # User confirmed the data
        whiptail --msgbox "Data confirmed. Proceeding..." 10 40 --title "Success"
        break
    else
        # User chose to cancel and restart
        whiptail --msgbox "Restarting the data entry process..." 10 40 --title "Restarting"
    fi
done

########################
#   Cockpit
########################


# Step 1 - Install Cockpit
sudo apt update && sudo apt upgrade -y

echo "Installing Cockpit..."
sudo apt install -y cockpit

# Step 2 - Install Cockpit Plugin for Dashboard Charts
echo "Installing Cockpit PCP plugin for enhanced dashboard charts..."
sudo apt -y install cockpit-pcp

# Step 3 - Ensure all drives mount at startup
echo "Configuring all drives to mount at startup..."
# Note: Adjust specific drive mounting settings if required

# Step 4 - Install Tuned for performance tuning
echo "Installing Tuned..."
sudo apt-get install -y tuned

# Step 5 - Configure Network Manager to avoid update issues
echo "Editing Network Manager configuration to handle fake interface issue..."
sudo tee /etc/NetworkManager/conf.d/10-globally-managed-devices.conf > /dev/null <<EOL
[keyfile]
unmanaged-devices=none
EOL

# Add a fake network interface
echo "Adding a fake network interface to avoid update issues..."
sudo nmcli con add type dummy con-name fake ifname fake0 ip4 1.2.3.4/24 gw4 1.2.3.1

# Step 6 - Set timezone and configure NTP servers
echo "Setting timezone to Europe/Vienna..."
sudo timedatectl set-timezone Europe/Vienna

echo "Configuring NTP servers..."
sudo tee /etc/systemd/timesyncd.conf > /dev/null <<EOL
[Time]
NTP=0.at.pool.ntp.org 1.at.pool.ntp.org 2.at.pool.ntp.org
FallbackNTP=bevtime1.metrologie.at bevtime2.metrologie.at time.metrologie.at ts1.aco.net ts2.aco.net
EOL

sudo systemctl restart systemd-timesyncd --quiet --no-pager
sudo systemctl start cockpit --quiet --no-pager
sudo systemctl enable cockpit --quiet --no-pager

# Step 7 - Update all systems
echo "Updating all system packages..."
sudo apt update && sudo apt upgrade -y

########################
# Create Files
########################

cat << 'EOF' > /home/administrator/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oekovolt</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            background-color: white; /* Set background to black */
            color: white; /* Set text color to white for contrast */
            display: flex; /* Use flexbox for centering */
            flex-direction: column; /* Align items in a column */
            align-items: center; /* Center items horizontally */
            justify-content: center; /* Center items vertically */
            height: 100vh; /* Full height of the viewport */
            font-family: Arial, sans-serif; /* Font style */
        }
        /* Image styling */
        img {
            max-width: 40%; /* Responsive width */
            height: auto; /* Maintain aspect ratio */
            border-radius: 10px; /* Optional: rounded corners */
        }
    </style>
</head>
<body>
    <img src="/home/administrator/oekovolt.jpg" alt="Oekovolt Logo" />
</body>
</html>
EOF

cat << 'EOF' > /home/administrator/index2.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="google" content="notranslate">
    <title>Oekovolt</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            background-color: #ffffff; /* Dark background for better visibility */
            color: #ffffff; /* White text for contrast */
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh; /* Full height of the viewport */
            font-family: 'Arial', sans-serif; /* Font style */
            text-align: center; /* Center text */
            padding: 20px; /* Add padding for spacing */
        }
        .main {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            width: 100%; /* Full width */
            max-width: 800px; /* Limit max width for large screens */
        }
        /* Image styling */
        img {
            max-width: 90%; /* Responsive width */
            height: auto; /* Maintain aspect ratio */
            border-radius: 10px; /* Optional: rounded corners */
            margin-bottom: 30px; /* Space below the image */
        }
        .header2 {
            font-size: 20px; /* Larger font size for readability */
            color: black; /* Ensure text is visible */
            margin-top: 10%;
            text-align: center;
            padding: 0 20px; /* Add padding for smaller screens */
        }
        .header3{
            font-size: 18px;
            color: black; 
            font-weight: normal;
            text-align: center;
            padding: 0 20px;
        }
        /* Media queries for responsiveness */
        @media (max-width: 768px) {
            .header2 {
                font-size: 20px; /* Slightly smaller font on mobile */
            }
            img {
                max-width: 100%; /* Increase image width on mobile */
            }
        }
        @media (max-width: 480px) {
            .header2 {
                font-size: 18px; /* Further reduce font size on very small screens */
            }
        }
    </style>
</head>
<body>
    <div class="main">
        <img src="/home/administrator/oekovolt.jpg" alt="Oekovolt Logo" />
        <h2 class="header2">HINWEIS: Die Verbindung zum PV-Regler ist momentan gestört.</h2>
        <h3 class="header3">Bitte überprüfen Sie Ihr Netzwerk oder führen Sie einen Neustart des PV-Reglers durch. Bei weiteren Problemen wenden Sie sich bitte an Ihren Administrator.</h3>
    </div>
</body>
</html>
EOF


cat << 'EOF' > /home/administrator/run_script.sh
cd google_logic
python3 selenium_logic.py &
EOF

mkdir google_logic

cat << 'EOF' > /home/administrator/google_logic/page_content.txt
logs
EOF

cat << 'EOF' > /home/administrator/google_logic/selenium_logic.py
import time
import os
import json
import chromedriver_autoinstaller  # type: ignore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options 
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import NoSuchElementException, WebDriverException
import pytesseract
import cv2
import requests

with open('creditentials.txt', 'r') as credentials:
    # Read the first three lines
    url = credentials.readline().strip()  # First line is URL
    username = credentials.readline().strip()  # Second line is username
    password = credentials.readline().strip()  # Third line is password
    photoId = credentials.readline().strip() # Fourth line is photo ID
    photoId2 = credentials.readline().strip()
    photoId3 = credentials.readline().strip()
# Function to inject cookies into a new Chrome session
def add_cookies_to_browser(driver, cookies, url):
    driver.get(url)  # Load the page to set the cookies for
    for cookie in cookies:
        driver.add_cookie(cookie)  # Add each cookie to the browser
    driver.get(url) 

chrome_options = Options()
chrome_options.add_argument("--headless")  # Uncomment if you want to run in headless mode
chrome_options.add_argument("--no-sandbox")
chrome_options.add_argument("--disable-dev-shm-usage")
chrome_options.add_argument("--disable-infobars")  # Remove info bars
chrome_options.add_argument("--disable-extensions")
chrome_options.add_argument("--disable-features=TranslateUI")
prefs = {
        "profile.password_manager_enabled": False,
        "credentials_enable_service": False
        }
chrome_options.add_experimental_option("prefs", prefs)
chrome_options.add_argument("--kiosk")  # Add this for kiosk mode

# # Disable the "Chrome is being controlled" notification
# chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])

# Create a service object for ChromeDriver
service = Service()

# URL to be accessed

# Function to check if the specified URL has a connection
def is_connected_to_url(url):
    try:
        response = requests.get(url, timeout=5)
        return response.status_code == 200
    except (requests.ConnectionError, requests.Timeout):
        return False
    
def check_for_no_data(driver):
    # Take a screenshot of the current window
    driver.save_screenshot("screenshot.png")

    # Load the screenshot using OpenCV
    img = cv2.imread("screenshot.png")
    
    # Convert to grayscale for better text recognition
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Use OCR (Optical Character Recognition) to detect text
    # Here we use pytesseract to do the OCR, make sure to install it first.
    # If not installed, run: pip install pytesserac

    # Extract text from the image
    extracted_text = pytesseract.image_to_string(gray)

    # Check if "no data" is in the extracted text
    if "no data available" in extracted_text.lower():
        print("Found 'no data' in the display. Restarting the process...")
        return True
    return False
    

def run_process(chrome_options):
    # i= 0
    while True:
        driver = webdriver.Chrome(service=service, options=chrome_options)

        try:
            # Step 3: Navigate to the page
            driver.get(url)

            # Wait for the page to load
            time.sleep(3)

            # Check if the image is present
            try:
                if driver.find_element(By.ID, 'login-title') or driver.find_element(By.ID, 'login-logo'):
                    print("Login logo is present. Proceeding with login.")

                    # Proceed with login actions
                    username_field = driver.find_element(By.NAME, 'j_username')
                    username_field.send_keys(username)  # Replace with the correct username
                    print("Value 'tv' has been set in the username field.")

                    submit_button = driver.find_element(By.ID, 'login-submit')
                    submit_button.click()
                    print("Login button clicked (username submission).")

                    time.sleep(3)  # Wait for the login to process

                    cookies = driver.get_cookies()
                    print(f"Cookies after username submission: {cookies}")

                    password_field = driver.find_element(By.NAME, 'j_password')
                    password_field.send_keys(password)  # Replace with your actual password
                    print("Password has been set in the password field.")

                    submit_button = driver.find_element(By.ID, 'login-submit')
                    submit_button.click()
                    print("Login button clicked (password submission).")

                    time.sleep(3)  # Wait for the login to process

                    cookies = driver.get_cookies()
                    print(f"Cookies after password submission: {cookies}")

                    # Open a new Chrome instance (non-headless) to load cookies and visit the URL
                    chrome_options = Options()
                    chrome_options.add_argument("--disable-blink-features=AutomationControlled")
                    chrome_options.add_argument("--kiosk")  # Add this for kiosk mode
                    chrome_options.add_argument("--no-first-run")
                    chrome_options.add_argument("--disable-extensions")  # Disable extensions
                    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
                    chrome_options.add_experimental_option('useAutomationExtension', False)
                    chrome_options.add_argument("--start-maximized")
                    
                    driver = webdriver.Chrome(service=service, options=chrome_options)

                    # Inject cookies into the new browser session
                    add_cookies_to_browser(driver, cookies, url)

                    # driver.execute_script(f"document.body.style.zoom=1.5;")

                time.sleep(20)  # Wait for the page to load
                while True:
                    try:
                        # Check for specific element
                        with open("page_content.txt", "w", encoding="utf-8") as file:
                            file.write(driver.page_source)
                        element_found = False
    
                        try:
                            if driver.find_element(By.ID, photoId):
                                print(f"Element with id {photoId} exists.")
                                element_found = True
                        except:
                            print(f"Element with id {photoId} not found.")
                        
                        try:
                            if driver.find_element(By.ID, photoId2):
                                print(f"Element with id {photoId2} exists.")
                                element_found = True
                        except:
                            print(f"Element with id {photoId2} not found.")
                        
                        try:
                            if driver.find_element(By.ID, photoId3):
                                print(f"Element with id {photoId3} exists.")
                                element_found = True
                        except:
                            print(f"Element with id {photoId3} not found.")
                        
                        if element_found:
                            time.sleep(25)
                        else:
                            driver.find_element(By.ID, 'zcmsaodfjvadsfkjafnjsjdf')

                        if check_for_no_data(driver):
                           driver.refresh()
                            
                    except:
                        print("Element with id='root.content.Picture2.img' does not exist. Re-logging in...")
                        # Attempt to reconnect to the URL
                        if is_connected_to_url(url):
                            run_process(chrome_options)  # Retry the process if connected
                        else:
                            try:
                                body = driver.find_element(By.TAG_NAME, 'body')
                                if "Cannot display page" in body.text.lower():
                                    print("Content cannot be displayed. Redirecting to index.html.")
                                    os.system("google-chrome --kiosk --no-first-run --disable-translate --disable-features=TranslateUI --lang=en-US /home/administrator/index2.html")
                            except:
                                print("WebDriver encountered an issue. Redirecting to index.html.")
                                time.sleep(1)
                                os.system("google-chrome --kiosk --no-first-run --disable-translate --disable-features=Translate --lang=en-US /home/administrator/index2.html")
                            time.sleep(2)
                            print("Connection not reachable, redirecting to index.html.")
                            os.system("google-chrome --kiosk --no-first-run --disable-translate --disable-features=Translate --lang=en-US /home/administrator/index2.html")
                            time.sleep(1)
            except:
                print("Login logo is not present. Retrying in 5 seconds...")

        except Exception as e:
            print(f"An error occurred: {e}")

run_process(chrome_options)
EOF

cat << EOF > /home/administrator/google_logic/creditentials.txt
http://$IP_ADDRESS
$USERNAME
$PASSWORD
$FIRST_VALIDATION
$SECOND_VALIDATION
$THIRD_VALIDATION
EOF

run commands

#########################
# Install Commands
#########################

wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo chown administrator:administrator /home/administrator/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb

sudo apt install -y openbox

touch /home/administrator/.Xauthority


# Function to create .xinitrc for horizontal mode
create_horizontal_xinitrc() {
    cat << 'EOF' > /home/administrator/.xinitrc
#!/bin/bash
# Start Openbox

# Disable DPMS (Energy Star) features
xset -dpms

# Disable screen blanking
xset s off

# Disable screensaver
xset s noblank

unclutter-xfixes -idle 0 &
x11vnc -nopw -display :0 -forever -loop -noxdamage &

openbox-session &
# Start Google Chrome in Kiosk Mode
./run_script.sh
google-chrome --kiosk --no-first-run --disable-translate /home/administrator/index.html
logout() {
  echo "Logging out from Openbox..."
  openbox --exit

  echo "Logging out from user account..."
  pkill -KILL -u $USER
}
logout
EOF
    echo "Horizontal .xinitrc created."
}

# Function to create .xinitrc for vertical mode
create_vertical_xinitrc() {
    cat << 'EOF' > /home/administrator/.xinitrc
#!/bin/bash
# Start Openbox

# Get the connected display name
DISPLAY_NAME=$(xrandr | grep " connected" | awk '{ print $1 }')

# Set display to portrait mode
if [ -n "$DISPLAY_NAME" ]; then
  xrandr --output "$DISPLAY_NAME" --rotate right
else
  echo "No connected display found."
fi

# Disable DPMS (Energy Star) features
xset -dpms

# Disable screen blanking
xset s off

# Disable screensaver
xset s noblank

unclutter-xfixes -idle 0 &
x11vnc -nopw -display :0 -forever -loop -noxdamage &

openbox-session &
# Start Google Chrome in Kiosk Mode
cd /home/administrator

./run_script.sh
google-chrome --kiosk --no-first-run --disable-translate /home/administrator/index.html
logout() {
  echo "Logging out from Openbox..."
  openbox --exit

  echo "Logging out from user account..."
  pkill -KILL -u $USER
}
logout
EOF
    echo "Vertical .xinitrc created."
}
case $CHOICE in
    1)
        create_horizontal_xinitrc
        ;;
    2)
        create_vertical_xinitrc
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

chmod +x /home/administrator/.xinitrc
sudo apt install -y xorg

cat << 'EOF' > /home/administrator/.bash_profile
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    startx
fi
EOF

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

cat << 'EOF' > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin administrator --noclear %I $TERM
EOF

sudo usermod -aG video administrator
sudo systemctl daemon-reload
wait
sudo systemctl restart getty@tty1
sudo chmod +x run_script.sh
sudo chmod +x /home/administrator/google_logic/selenium_logic.py
sudo chmod +x /home/administrator/google_logic/creditentials.txt
sudo apt update
sudo apt install -y python3-full python3 python3-venv python3-pip
cd /home/administrator/google_logic
python3 -m venv env
wait
source env/bin/activate
sudo apt-get install -y unclutter-xfixes
wait
sudo apt install -y x11vnc
wait
sudo apt install -y tesseract-ocr
wait
pip install opencv-python pytesseract selenium requests chromedriver-autoinstaller pyxdg
wait
deactivate
pip install opencv-python pytesseract selenium requests chromedriver-autoinstaller pyxdg

sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=0"/' /etc/default/grub

sudo update-grub
wait

cat <<EOF >> /etc/default/grub

# this is my blacklist
blacklist iwlwifi
blacklist btusb
blacklist bluetooth
blacklist btrtl
blacklist intel_bt
EOF

sudo update-initramfs -u
wait

sudo cp /home/administrator/ubuntu-logo.png /usr/share/plymouth/ubuntu-logo.png
sudo cp /home/administrator/ubuntu-logo.png /usr/share/plymouth/themes/spinner/watermark.png

######################################
# Install Crowdsec
######################################

# Update system packages
echo "Updating system packages..."
sudo apt update -y

# Install CrowdSec
echo "Installing CrowdSec..."
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash
sudo apt-get install crowdsec -y

# Install CrowdSec firewall bouncer
echo "Installing CrowdSec Firewall Bouncer for IPTables..."
sudo apt install -y crowdsec-firewall-bouncer-iptables


while true; do
    enrollment_token=$(whiptail --inputbox "Enter your CrowdSec enrollment token:" 8 78 --title "CrowdSec Enrollment Token" 3>&1 1>&2 2>&3)
    if [[ -z "$enrollment_token" ]]; then
        whiptail --msgbox "Enrollment token is required to proceed. Exiting script." 8 78
        exit 1
    fi

    # Retry enrollment command with a delay and --overwrite on subsequent attempts
    max_attempts=3
    attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        echo "Attempt $attempt out of $max_attempts for enrollment..."

        if [[ $attempt -eq 1 ]]; then
            # First attempt without --overwrite
            sudo cscli console enroll -e context "$enrollment_token" > /dev/null 2>&1 && break
        else
            # Subsequent attempts with --overwrite
            sudo cscli console enroll -e context "$enrollment_token" --overwrite > /dev/null 2>&1 && break
        fi

        echo "Enrollment attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done

    # Check if enrollment was successful
    if [[ $attempt -le $max_attempts ]]; then
        break  # Exit the loop if enrollment was successful
    else
        whiptail --msgbox "Enrollment failed after $max_attempts attempts. Please re-enter the enrollment token." 8 78
    fi
done
# After countdown, show a button to proceed
whiptail --title "Enrollment Confirmation" --msgbox "Please Accept Enrollment Token in https://www.crowdsec.com If you have accepted the enrollment in CrowdSec, press OK to continue." 8 78

# Install SSHd parsers and scenarios
echo "Installing SSHd parsers and scenarios..."
sudo cscli collections install crowdsecurity/sshd
sudo cscli parsers install crowdsecurity/sshd-logs
sudo cscli scenarios install crowdsecurity/ssh-bf

# Restart CrowdSec to apply changes
echo "Restarting CrowdSec..."
sudo systemctl restart crowdsec

# Optional: Display current CrowdSec hub list and metrics
sudo cscli hub list
sudo cscli metrics

# Configure whitelist using whiptail for dynamic IP and CIDR input
echo "Configuring CrowdSec whitelist..."
whitelist_file="/etc/crowdsec/parsers/s02-enrich/whitelists.yaml"

# Remove specific CIDR ranges if they exist
sudo sed -i '/192.168.0.0\/16/d' "$whitelist_file"
sudo sed -i '/10.0.0.0\/8/d' "$whitelist_file"
sudo sed -i '/172.16.0.0\/12/d' "$whitelist_file"

# Function to validate IP address format
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        for part in $(echo "$ip" | tr "." " "); do
            if (( part < 0 || part > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to validate CIDR format
validate_cidr() {
    local cidr="$1"
    if [[ $cidr =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}$ ]]; then
        local ip=${cidr%/*}
        local range=${cidr#*/}
        validate_ip "$ip" && (( range >= 0 && range <= 32 )) && return 0 || return 1
    else
        return 1
    fi
}

# Prompt user for IP addresses to add to the IP list
while true; do
    ip=$(whiptail --inputbox "Enter an IP address to whitelist (leave blank to stop):" 8 78 --title "Add IP to Whitelist" 3>&1 1>&2 2>&3)
    if [[ -z "$ip" ]]; then
        break
    fi
    if validate_ip "$ip"; then
        # Use sed to insert the IP under the ip: section within whitelist
        sudo sed -i "/^  ip:/a\    - \"$ip\"" "$whitelist_file"
    else
        whiptail --msgbox "Invalid IP address. Please enter a valid IP." 8 78
    fi
done

# Prompt user for CIDRs to add to the CIDR list
while true; do
    cidr=$(whiptail --inputbox "Enter a CIDR range to whitelist (leave blank to stop):" 8 78 --title "Add CIDR to Whitelist" 3>&1 1>&2 2>&3)
    if [[ -z "$cidr" ]]; then
        break
    fi
    if validate_cidr "$cidr"; then
        # Use sed to insert the CIDR under the cidr: section within whitelist
        sudo sed -i "/^  cidr:/a\    - \"$cidr\"" "$whitelist_file"
    else
        whiptail --msgbox "Invalid CIDR. Please enter a valid CIDR." 8 78
    fi
done

# Reload CrowdSec to apply changes
echo "Reloading CrowdSec to apply whitelist changes..."
sudo systemctl reload crowdsec
whiptail --msgbox "Whitelist updated and CrowdSec reloaded successfully." 8 78


# Install all CrowdSec scenarios
echo "Installing all CrowdSec scenarios..."
for scenario in $(sudo cscli scenarios list --all | awk '{print $1}' | grep 'crowdsecurity/'); do
    sudo cscli scenarios install "$scenario"
done

# Final reload to apply all configurations
sudo systemctl restart crowdsec
wait
sudo systemctl reload crowdsec
wait

#!/bin/bash

# Step 1: Create the script_crowdsec.sh file with the required content
echo "Creating /home/administrator/script_crowdsec.sh..."

cat << 'EOF' > /home/administrator/script_crowdsec.sh
#!/bin/bash

# Function to check and start a service
check_and_start_service() {
    service_name=$1
    status=$(systemctl is-active $service_name)
    if [ "$status" == "active" ]; then
        echo "$service_name is running."
    else
        echo "$service_name is not running. Attempting to start..."
        sudo systemctl start $service_name
        new_status=$(systemctl is-active $service_name)
        if [ "$new_status" == "active" ]; then
            echo "$service_name started successfully."
        else
            echo "Failed to start $service_name."
        fi
    fi
}

# Check and start CrowdSec service
check_and_start_service crowdsec

# Check and start CrowdSec Firewall Bouncer service
check_and_start_service crowdsec-firewall-bouncer
EOF

# Step 2: Make the script executable
echo "Setting execute permissions for /home/administrator/script_crowdsec.sh..."
sudo chmod +x /home/administrator/script_crowdsec.sh

# Step 3: Add a cron job to run this script every 10 minutes
echo "Adding cron job to execute /home/administrator/script_crowdsec.sh every 10 minutes..."

CRON_JOB="*/10 * * * * /home/administrator/script_crowdsec.sh >> /home/administrator/crowdsec_service_check.log"

# Check if the cron job already exists
(crontab -l 2>/dev/null | grep -F "$CRON_JOB") && echo "Cron job already exists. No changes made." || (
    # Add the cron job if it does not exist
    echo "Adding cron job to execute /home/administrator/script_cron_cockpit.sh every 10 minutes..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job added successfully."
)

sudo chmod 777 /home/administrator/.xinitrc 
sudo chmod 777 /home/administrator/.Xauthority
sudo chmod 777 /home/administrator/google_logic
sudo chmod 777 /home/administrator/google_logic/selenium_logic.py 
sudo chmod 777 /home/administrator/google_logic/creditentials.txt
sudo chmod 777 /home/administrator/google_logic/page_content.txt 
sudo chmod 777 /home/administrator/run_script.sh 
sudo chmod 777 /home/administrator/script_crowdsec.sh 
sudo chmod 777 /home/administrator/index.html 
sudo chmod 777 /home/administrator/index2.html 
sudo chmod 777 /home/administrator/.bash_profile

echo "Installation and configuration complete!"

sudo reboot