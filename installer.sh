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
from gi.repository import Gtk, AppIndicator3, GLib
import subprocess
import logging
import signal
import os

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

PROFILES_PER_PAGE = 10

class TunedIndicator:
    def __init__(self):
        self.indicator = AppIndicator3.Indicator.new(
            "tuned-indicator",
            "gnome-power-manager-symbolic",
            AppIndicator3.IndicatorCategory.SYSTEM_SERVICES)
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.current_page = 0
        self.indicator.set_menu(self.create_menu())

        # Delay initial update to ensure system is ready
        GLib.timeout_add_seconds(5, self.initial_update)

        # Setup signal handlers for system events
        GLib.timeout_add_seconds(10, self.update_active_profile)
        signal.signal(signal.SIGUSR1, self.handle_signal)
        signal.signal(signal.SIGUSR2, self.handle_signal)

    def create_menu(self):
        self.menu = Gtk.Menu()
        self.update_menu_items()
        return self.menu

    def get_profiles(self):
        try:
            output = subprocess.check_output(['tuned-adm', 'list'], stderr=subprocess.STDOUT, text=True)
            profiles = [line.strip('- ').split(' - ')[0].strip() for line in output.split('\n') if line.startswith('- ')]
            return profiles
        except subprocess.CalledProcessError as e:
            logging.error(f"Error getting profiles: {e.output}")
            return []

    def update_menu_items(self):
        # Clear existing menu items
        for item in self.menu.get_children():
            self.menu.remove(item)

        profiles = self.get_profiles()
        start = self.current_page * PROFILES_PER_PAGE
        end = min(start + PROFILES_PER_PAGE, len(profiles))
        current_profiles = profiles[start:end]

        for profile in current_profiles:
            item = Gtk.MenuItem(label=profile)
            item.set_tooltip_text(profile)  # Ensure the full profile name is visible
            item.connect('activate', self.on_profile_click)
            self.menu.append(item)

        # Add pagination controls
        if self.current_page > 0:
            prev_item = Gtk.MenuItem(label="Previous")
            prev_item.connect('activate', self.on_prev_page)
            self.menu.append(prev_item)

        if end < len(profiles):
            next_item = Gtk.MenuItem(label="Next")
            next_item.connect('activate', self.on_next_page)
            self.menu.append(next_item)

        separator = Gtk.SeparatorMenuItem()
        self.menu.append(separator)

        off_item = Gtk.MenuItem(label="Turn Off Applet")
        off_item.connect('activate', self.on_turn_off_applet_click)
        self.menu.append(off_item)

        self.menu.show_all()

    def on_prev_page(self, widget):
        if self.current_page > 0:
            self.current_page -= 1
            self.update_menu_items()

    def on_next_page(self, widget):
        profiles = self.get_profiles()
        if (self.current_page + 1) * PROFILES_PER_PAGE < len(profiles):
            self.current_page += 1
            self.update_menu_items()

    def on_profile_click(self, widget):
        profile = widget.get_label()
        # Special handling for the specific profile
        if profile.startswith('intel-best_power_efficiency_mode'):
            profile = 'intel-best_power_efficiency_mode'
        try:
            subprocess.check_output(['tuned-adm', 'profile', profile], stderr=subprocess.STDOUT, text=True)
            logging.info(f"Successfully switched to profile: {profile}")
            self.update_active_profile()
        except subprocess.CalledProcessError as e:
            logging.error(f"Failed to switch profile: {e.output}")

    def on_turn_off_applet_click(self, widget):
        logging.info("Turning off the applet")
        os._exit(0)  # Exit the applet

    def update_active_profile(self):
        try:
            output = subprocess.check_output(['tuned-adm', 'active'], stderr=subprocess.STDOUT, text=True)
            if "No current active profile" in output:
                self.indicator.set_label(" No active profile", "")
            else:
                active_profile = output.strip().split(':')[-1].strip()
                self.indicator.set_label(f" {active_profile}", "")
        except subprocess.CalledProcessError as e:
            logging.error(f"Error getting active profile: {e.output}")
            self.indicator.set_label(" Unknown", "")
        return True

    def initial_update(self):
        self.update_active_profile()
        return False  # Ensures the timeout runs only once

    def handle_signal(self, signum, frame):
        if signum in (signal.SIGUSR1, signal.SIGUSR2):
            self.update_active_profile()

if __name__ == "__main__":
    indicator = TunedIndicator()
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
