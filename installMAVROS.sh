#!/bin/bash
# Install Robot Operating System (ROS) on NVIDIA Jetson TX
# Maintainer of ARM builds for ROS is http://answers.ros.org/users/1034/ahendrix/
# Information from:
# http://wiki.ros.org/kinetic/Installation/UbuntuARM

# Red is 1
# Green is 2
# Reset is sgr0


if [ $(id -u) -ne 0 ]; then
   echo >&2 "Must be run as root"
   exit 1
fi

set -e
set -x

export NORMAL_USER=nvidia

#pushd $HOME

apt-get install python-rosinstall python-rosinstall-generator python-wstool python-catkin-tools build-essential python-rosdep ninja-build -y

#This must be done as regular user!!!! change!!!
sudo -u $NORMAL_USER -H bash <<'EOF'
set -e
set -x

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

pushd $HOME

export CATKIN_WS=NvidiaKaya_ws
export ROS_DISTRO=melodic

#TODO change kinetic to $ROS_DISTRO but its not defined at this point
source /opt/ros/$ROS_DISTRO/setup.bash

tput setaf 2
echo "Setup Catking Workspace"
tput sgr0

rm -rf $CATKIN_WS 
mkdir -p $CATKIN_WS/src
pushd $CATKIN_WS
catkin_init_workspace

tput setaf 2
echo "Cloning packages into workspace src folder"
tput sgr0

pushd src
git clone https://github.com/Slamtec/rplidar_ros.git
git clone https://github.com/GT-RAIL/robot_pose_publisher.git


git clone https://github.com/jmachuca77/mavlink-gbp-release mavlink
pushd mavlink
git checkout release/melodic/mavlink
popd
git clone https://github.com/jmachuca77/mavros.git
pushd mavros
git checkout master
popd

popd

tput setaf 2
echo "Setting up Google Cartographer settings"
tput sgr0

wstool init src
wstool merge -t src https://raw.githubusercontent.com/googlecartographer/cartographer_ros/master/cartographer_ros.rosinstall
wstool update -t src
pushd $HOME/$CATKIN_WS/src/cartographer/scripts
./install_proto3.sh
popd

tput setaf 2
echo "Running rosdep init and update"
tput sgr0

sudo rosdep init || true   # if error message appears about file already existing, just ignore and continue
sudo rosdep fix-permissions
rosdep update
#rosdep install --from-paths src --ignore-src --rosdistro=${ROS_DISTRO} -y
rosdep install --from-paths src --ignore-src --rosdistro=${ROS_DISTRO} -y

tput setaf 2
echo "Modifying robot_pose_publisher.cpp, creating cartographer.launch and cartographer.lua"
tput sgr0

#Back to install folder
popd

cp $SOURCE_DIR/robot_pose_publisher.cpp $HOME/$CATKIN_WS/src/robot_pose_publisher/src
cp $SOURCE_DIR/cartographer.launch $HOME/$CATKIN_WS/src/cartographer_ros/cartographer_ros/launch
cp $SOURCE_DIR/cartographer.lua $HOME/$CATKIN_WS/src/cartographer_ros/cartographer_ros/configuration_files

tput setaf 2
echo "Building Catking Packages"
tput sgr0

pushd $HOME/$CATKIN_WS
time catkin build

tput setaf 2
echo "Add source Catking WS to .bashrc (todo)"
tput sgr0

pushd $HOME
grep -q -F 'source /home/$NORMAL_USER/$CATKIN_WS/devel/setup.bash' ~/.bashrc || echo "source /home/$NORMAL_USER/$CATKIN_WS/devel/setup.bash" >> ~/.bashrc
. ~/.bashrc


EOF

tput setaf 2
echo "Install geographiclib datasets"
sudo /opt/ros/$ROS_DISTRO/lib/mavros/install_geographiclib_datasets.sh
tput sgr0

tput setaf 2
echo "Installation complete! Please reboot for changes to take effect"
tput sgr0
