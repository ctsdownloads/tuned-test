#!/bin/bash

# Install dependencies
sudo apt update
sudo apt install -y python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-appindicator3-0.1 tuned

# Create directory for the script
mkdir -p ~/.local/bin

# Create the Python script
cat << EOF > ~/.local/bin/tuned_indicator.py
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3
import subprocess
import logging

# Your Python script content goes here
# (Paste the entire Python script here)
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3
import subprocess
import logging

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

class TunedIndicator:
    def __init__(self):
        self.indicator = AppIndicator3.Indicator.new(
            "tuned-indicator",
            "gnome-power-manager-symbolic",
            AppIndicator3.IndicatorCategory.SYSTEM_SERVICES)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.create_menu())

    def create_menu(self):
        menu = Gtk.Menu()
        
        profiles = self.get_profiles()
        for profile in profiles:
            item = Gtk.MenuItem(label=profile)
            item.connect('activate', self.on_profile_click)
            menu.append(item)

        separator = Gtk.SeparatorMenuItem()
        menu.append(separator)

        off_item = Gtk.MenuItem(label="Turn Off")
        off_item.connect('activate', self.on_turn_off_click)
        menu.append(off_item)

        menu.show_all()
        return menu

    def get_profiles(self):
        try:
            cmd = ['tuned-adm', 'list']
            output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
            
            profiles = []
            for line in output.split('\n'):
                if line.startswith('- '):
                    profile = line.strip('- ').split(' - ')[0].strip()
                    profiles.append(profile)
            
            return profiles
        except subprocess.CalledProcessError as e:
            logging.error(f"Error getting profiles: {e.output}")
            return []

    def on_profile_click(self, widget):
        profile = widget.get_label()
        try:
            cmd = ['pkexec', 'tuned-adm', 'profile', profile]
            subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
            self.show_info_dialog(f"Successfully switched to profile: {profile}")
            self.update_active_profile()
        except subprocess.CalledProcessError as e:
            self.show_error_dialog(f"Failed to switch profile: {e.output}")

    def on_turn_off_click(self, widget):
        try:
            cmd = ['pkexec', 'tuned-adm', 'off']
            subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
            self.show_info_dialog("Successfully turned off TuneD")
            self.update_active_profile()
        except subprocess.CalledProcessError as e:
            self.show_error_dialog(f"Failed to turn off TuneD: {e.output}")

    def update_active_profile(self):
        try:
            cmd = ['tuned-adm', 'active']
            output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
            active_profile = output.strip().split(':')[-1].strip()
            self.indicator.set_label(f" {active_profile}", "")
        except subprocess.CalledProcessError as e:
            logging.error(f"Error getting active profile: {e.output}")
            self.indicator.set_label(" Unknown", "")

    def show_error_dialog(self, message):
        dialog = Gtk.MessageDialog(
            transient_for=None,
            flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="Error",
        )
        dialog.format_secondary_text(message)
        dialog.run()
        dialog.destroy()

    def show_info_dialog(self, message):
        dialog = Gtk.MessageDialog(
            transient_for=None,
            flags=0,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text="Information",
        )
        dialog.format_secondary_text(message)
        dialog.run()
        dialog.destroy()

if __name__ == "__main__":
    indicator = TunedIndicator()
    indicator.update_active_profile()
    Gtk.main()

EOF

# Make the script executable
chmod +x ~/.local/bin/tuned_indicator.py

# Create autostart desktop entry
mkdir -p ~/.config/autostart
cat << EOF > ~/.config/autostart/tuned-indicator.desktop
[Desktop Entry]
Type=Application
Exec=/usr/bin/python3 ${HOME}/.local/bin/tuned_indicator.py
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=TuneD Indicator
Name=TuneD Indicator
Comment[en_US]=TuneD profile switcher indicator
Comment=TuneD profile switcher indicator
EOF

echo "Installation complete. The TuneD Indicator will start automatically on your next login."
echo "To start it now without logging out, run: python3 ~/.local/bin/tuned_indicator.py"
