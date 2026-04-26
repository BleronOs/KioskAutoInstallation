#!/bin/bash

########################
#   Check for Auto Mode
########################

AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

########################
#   Set Data (Interactive or Auto)
########################

if [ "$AUTO_MODE" = false ]; then
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
        
        if [[ $ip =~ $valid_ip_regex ]]; then
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

        vars=("IP_ADDRESS" "USERNAME" "PASSWORD" "FIRST_VALIDATION" "SECOND_VALIDATION" "THIRD_VALIDATION")
        prompts=(
            "Enter the IP address:"
            "Enter the username:"
            "Enter the password:"
            "Enter the first validation value:"
            "Enter the second validation value:"
            "Enter the third validation value:"
        )

        for i in "${!vars[@]}"; do
            var_name=${vars[$i]}
            prompt_message=${prompts[$i]}
            default_value=""

            while true; do
                read_value=$(prompt_for_input "$var_name" "$prompt_message" "$default_value")
                
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

    # Main script loop for interactive mode
    while true; do
        collect_data
        CHOICE=$(whiptail --nocancel --title "Kiosk Setup" --menu "Choose the orientation for the kiosk:" 10 60 2 \
        "1" "Horizontal" \
        "2" "Vertical" 3>&1 1>&2 2>&3)

        if [ "$CHOICE" -eq 1 ]; then
            KIOSK_TYPE="Horizontal"
        elif [ "$CHOICE" -eq 2 ]; then
            KIOSK_TYPE="Vertical"
        else
            KIOSK_TYPE="Unknown"
        fi

        if whiptail --yesno "Data Collected:
IP Address: $IP_ADDRESS
Username: $USERNAME
Password: $PASSWORD
First Validation: $FIRST_VALIDATION
Second Validation: $SECOND_VALIDATION
Third Validation: $THIRD_VALIDATION
Type of Kiosk: $KIOSK_TYPE

Is this information correct?" 20 60 --title "Confirm Data"; then
            whiptail --msgbox "Data confirmed. Proceeding..." 10 40 --title "Success"
            break
        else
            whiptail --msgbox "Restarting the data entry process..." 10 40 --title "Restarting"
        fi
    done
else
    # Auto mode - use default values
    IP_ADDRESS="127.0.0.1"
    USERNAME=""
    PASSWORD=""
    FIRST_VALIDATION=""
    SECOND_VALIDATION=""
    THIRD_VALIDATION=""
    CHOICE=1  # Horizontal as default
    KIOSK_TYPE="Horizontal"
    
    echo "=========================================="
    echo "Auto Mode - Using default values:"
    echo "IP Address: $IP_ADDRESS"
    echo "Username: (empty)"
    echo "Password: (empty)"
    echo "Validation IDs: (empty)"
    echo "Kiosk Orientation: Horizontal"
    echo "=========================================="
    sleep 3
fi

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
sudo nmcli con add type dummy con-name fake ifname fake0 ip4 1.2.3.4/24 gw4 1.2.3.1 || true

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
# Install Google Chrome
########################

wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /tmp/
sudo apt install -y /tmp/google-chrome-stable_current_amd64.deb
rm -f /tmp/google-chrome-stable_current_amd64.deb

########################
# Install Required Packages
########################

sudo apt install -y openbox xorg python3-full python3-venv python3-pip unclutter-xfixes x11vnc tesseract-ocr xinit x11-xserver-utils

########################
# Create Directories
########################

mkdir -p /home/administrator/google_logic
mkdir -p /home/administrator/images

########################
# Create Files
########################

# Create index.html
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
            background-color: white;
            color: white;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            font-family: Arial, sans-serif;
        }
        img {
            max-width: 40%;
            height: auto;
            border-radius: 10px;
        }
    </style>
</head>
<body>
    <img src="/home/administrator/images/oekovolt.jpg" alt="Oekovolt Logo" />
</body>
</html>
EOF

# Create index2.html
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
            background-color: #ffffff;
            color: #ffffff;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            font-family: 'Arial', sans-serif;
            text-align: center;
            padding: 20px;
        }
        .main {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            width: 100%;
            max-width: 800px;
        }
        img {
            max-width: 90%;
            height: auto;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .header2 {
            font-size: 20px;
            color: black;
            margin-top: 10%;
            text-align: center;
            padding: 0 20px;
        }
        .header3{
            font-size: 18px;
            color: black;
            font-weight: normal;
            text-align: center;
            padding: 0 20px;
        }
        @media (max-width: 768px) {
            .header2 { font-size: 20px; }
            img { max-width: 100%; }
        }
        @media (max-width: 480px) {
            .header2 { font-size: 18px; }
        }
    </style>
</head>
<body>
    <div class="main">
        <img src="/home/administrator/images/oekovolt.jpg" alt="Oekovolt Logo" />
        <h2 class="header2">HINWEIS: Die Verbindung zum PV-Regler ist momentan gestört.</h2>
        <h3 class="header3">Bitte überprüfen Sie Ihr Netzwerk oder führen Sie einen Neustart des PV-Reglers durch. Bei weiteren Problemen wenden Sie sich bitte an Ihren Administrator.</h3>
    </div>
</body>
</html>
EOF

# Create run_script.sh
cat << 'EOF' > /home/administrator/run_script.sh
#!/bin/bash
cd /home/administrator/google_logic
source env/bin/activate
python3 selenium_logic.py
EOF

# Create page_content.txt
echo "logs" > /home/administrator/google_logic/page_content.txt

# Create selenium_logic.py
cat << 'EOF' > /home/administrator/google_logic/selenium_logic.py
import time
import os
import json
import chromedriver_autoinstaller
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options 
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import NoSuchElementException, WebDriverException
import pytesseract
import cv2
import requests

credentials_file = "/home/administrator/google_logic/creditentials.txt"

def read_credentials():
    with open(credentials_file, 'r') as f:
        url = f.readline().strip()
        username = f.readline().strip()
        password = f.readline().strip()
        photoId = f.readline().strip()
        photoId2 = f.readline().strip()
        photoId3 = f.readline().strip()
    return url, username, password, photoId, photoId2, photoId3

def add_cookies_to_browser(driver, cookies, url):
    driver.get(url)
    for cookie in cookies:
        driver.add_cookie(cookie)
    driver.get(url)

chrome_options = Options()
chrome_options.add_argument("--headless")
chrome_options.add_argument("--no-sandbox")
chrome_options.add_argument("--disable-dev-shm-usage")
chrome_options.add_argument("--disable-infobars")
chrome_options.add_argument("--disable-extensions")
chrome_options.add_argument("--disable-features=TranslateUI")
prefs = {
    "profile.password_manager_enabled": False,
    "credentials_enable_service": False
}
chrome_options.add_experimental_option("prefs", prefs)
chrome_options.add_argument("--kiosk")

service = Service()

def is_connected_to_url(url):
    try:
        response = requests.get(url, timeout=5)
        return response.status_code == 200
    except (requests.ConnectionError, requests.Timeout):
        return False

def check_for_no_data(driver):
    driver.save_screenshot("/tmp/screenshot.png")
    img = cv2.imread("/tmp/screenshot.png")
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    extracted_text = pytesseract.image_to_string(gray)
    if "no data available" in extracted_text.lower():
        print("Found 'no data' in the display. Restarting the process...")
        return True
    return False

def run_process():
    while True:
        driver = webdriver.Chrome(service=service, options=chrome_options)
        try:
            url, username, password, photoId, photoId2, photoId3 = read_credentials()
            driver.get(url)
            time.sleep(3)

            try:
                if driver.find_element(By.ID, 'login-title') or driver.find_element(By.ID, 'login-logo'):
                    print("Login logo is present. Proceeding with login.")
                    username_field = driver.find_element(By.NAME, 'j_username')
                    username_field.send_keys(username)
                    submit_button = driver.find_element(By.ID, 'login-submit')
                    submit_button.click()
                    time.sleep(3)
                    cookies = driver.get_cookies()
                    password_field = driver.find_element(By.NAME, 'j_password')
                    password_field.send_keys(password)
                    submit_button.click()
                    time.sleep(3)
                    cookies = driver.get_cookies()
                    
                    chrome_options2 = Options()
                    chrome_options2.add_argument("--disable-blink-features=AutomationControlled")
                    chrome_options2.add_argument("--kiosk")
                    chrome_options2.add_argument("--no-first-run")
                    chrome_options2.add_argument("--disable-extensions")
                    chrome_options2.add_experimental_option("excludeSwitches", ["enable-automation"])
                    chrome_options2.add_experimental_option('useAutomationExtension', False)
                    
                    driver.quit()
                    driver = webdriver.Chrome(service=service, options=chrome_options2)
                    add_cookies_to_browser(driver, cookies, url)

                time.sleep(20)
                while True:
                    try:
                        with open("page_content.txt", "w", encoding="utf-8") as file:
                            file.write(driver.page_source)
                        element_found = False
        
                        try:
                            if driver.find_element(By.ID, photoId):
                                print(f"Element with id {photoId} exists.")
                                element_found = True
                        except:
                            pass
                        
                        try:
                            if driver.find_element(By.ID, photoId2):
                                print(f"Element with id {photoId2} exists.")
                                element_found = True
                        except:
                            pass
                        
                        try:
                            if driver.find_element(By.ID, photoId3):
                                print(f"Element with id {photoId3} exists.")
                                element_found = True
                        except:
                            pass
                        
                        if element_found:
                            time.sleep(25)
                        else:
                            driver.find_element(By.ID, 'nonexistent')
                        
                        if check_for_no_data(driver):
                            driver.refresh()
                            
                    except Exception as e:
                        print(f"Error in main loop: {e}")
                        if is_connected_to_url(url):
                            driver.quit()
                            break
                        else:
                            os.system("google-chrome --kiosk --no-first-run --disable-translate /home/administrator/index2.html")
                            time.sleep(5)
                            
            except Exception as e:
                print(f"Login error: {e}")
                time.sleep(5)
                
        except Exception as e:
            print(f"Outer error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    run_process()
EOF

# Create credentials file
cat > /home/administrator/google_logic/creditentials.txt << EOL
http://$IP_ADDRESS
$USERNAME
$PASSWORD
$FIRST_VALIDATION
$SECOND_VALIDATION
$THIRD_VALIDATION
EOL

########################
# Setup Python Virtual Environment
########################

cd /home/administrator/google_logic
python3 -m venv env
source env/bin/activate
pip install opencv-python pytesseract selenium requests chromedriver-autoinstaller pyxdg
deactivate

########################
# Configure X11 and Auto-login
########################

touch /home/administrator/.Xauthority

# Create .xinitrc based on orientation choice
if [ "$CHOICE" -eq 2 ]; then
    # Vertical mode
    cat << 'EOF' > /home/administrator/.xinitrc
#!/bin/bash
DISPLAY_NAME=$(xrandr | grep " connected" | awk '{ print $1 }')
if [ -n "$DISPLAY_NAME" ]; then
  xrandr --output "$DISPLAY_NAME" --rotate right
fi
xset -dpms
xset s off
xset s noblank
unclutter-xfixes -idle 0 &
x11vnc -nopw -display :0 -forever -loop -noxdamage &
openbox-session &
cd /home/administrator
./run_script.sh
google-chrome --kiosk --no-first-run --disable-translate /home/administrator/index.html
EOF
else
    # Horizontal mode (default)
    cat << 'EOF' > /home/administrator/.xinitrc
#!/bin/bash
xset -dpms
xset s off
xset s noblank
unclutter-xfixes -idle 0 &
x11vnc -nopw -display :0 -forever -loop -noxdamage &
openbox-session &
cd /home/administrator
./run_script.sh
google-chrome --kiosk --no-first-run --disable-translate /home/administrator/index.html
EOF
fi

chmod +x /home/administrator/.xinitrc

# Create .bash_profile
cat << 'EOF' > /home/administrator/.bash_profile
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    startx
fi
EOF

# Configure auto-login
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin administrator --noclear %I $TERM
EOF

sudo usermod -aG video administrator

########################
# Configure GRUB
########################

sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=0"/' /etc/default/grub

sudo update-grub

########################
# Configure Blacklist Modules
########################

cat <<EOF | sudo tee -a /etc/default/grub > /dev/null

# this is my blacklist
blacklist iwlwifi
blacklist btusb
blacklist bluetooth
blacklist btrtl
blacklist intel_bt
EOF

sudo update-initramfs -u

########################
# Set Permissions
########################

sudo chown -R administrator:administrator /home/administrator
sudo chmod +x /home/administrator/run_script.sh
sudo chmod +x /home/administrator/google_logic/selenium_logic.py
sudo chmod 600 /home/administrator/google_logic/creditentials.txt
sudo chmod +x /home/administrator/.bash_profile

########################
# Install Crowdsec (Optional - requires manual token)
########################

# Skip Crowdsec installation in auto mode to avoid prompts
if [ "$AUTO_MODE" = false ]; then
    echo "Installing CrowdSec..."
    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash
    sudo apt-get install crowdsec -y
    sudo apt install -y crowdsec-firewall-bouncer-iptables
    
    # Crowdsec enrollment and configuration would go here
    echo "CrowdSec installation skipped in auto mode. Run manually if needed."
fi

########################
# Final Steps
########################

sudo systemctl daemon-reload
sudo systemctl restart getty@tty1
sudo systemctl enable cockpit
sudo systemctl start cockpit

echo "=========================================="
echo "Installation and configuration complete!"
echo "=========================================="

if [ "$AUTO_MODE" = true ]; then
    echo "Auto mode completed. Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
else
    echo "Press any key to reboot..."
    read -n 1
    sudo reboot
fi