#!/bin/bash
#
# BUILDS THE CUBE APP AND UPDATE ITS DOCS
#
# http://cubeapp.io

# Based on Igor Ramadas <igor.ramadas@zalando.de> System App install script.
# http://systemapp.io
#
# Author: Emanuel Lauria <emanuel.lauria@zalando.de>

# VARIABLES
# -------------------------------------------------------------------------

OS_TYPE=""
PKG_MANAGER=""
SILENT=0

# ENVIRONMENT CHECK AND SETUP
# -------------------------------------------------------------------------

# Check if script is running with root user.
checkRoot(){
    if [ `whoami` = root ]; then
        echo "ATTENTION!!!"
        echo "You're running the install script as root!"
        echo "Unless you want to run the app under root only, we recommend executing this script with a non-root user."
        echo "Do you want to proceed anyway?"

        select ryn in Yes No
        do
            case "$ryn" in
                Yes)
                    echo "Proceeding with root..."
                    break
                    ;;
                No)
                    echo "Aborting..."
                    exit 1
                    ;;
            esac
        done
    fi
}

# Check the current environment, set package and setup variables accordingly.
checkEnvironment(){
    OS_TYPE=`uname`

    if type yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif type brew &> /dev/null; then
        PKG_MANAGER="brew"
    elif type apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
    else
        if [ "$OS_TYPE" = "Darwin" ]; then
            installHomebrew
        fi
    fi

    if [ "$PKG_MANAGER" = "" ]; then
        echo "This install script does not support your system, we're sorry :-("
        echo "Supported systems: Linux Ubuntu, Debian, Fedora, CentOS, Red Hat, and Mac OS X."
        echo "Supported package managers: APT, YUM and Homebrew."
        echo ""
        echo "Please go to http://cubeapp.io to see how to install the Cube App manually."
        exit 1
    fi

    echo "Using package manager: $PKG_MANAGER"
    
    if [ "$PKG_MANAGER" = "brew" ]; then
        echo "We'll now update brew package definitions..."
        brew update
    fi

    echo ""
    echo "Now checking app dependencies..."
    echo ""
}

# Refresh the path / environment variables.
refreshEnvironment(){
    if [ "$OS_TYPE" = "Darwin" ]; then
        source ~/.bash_profile
    else
        source ~/.bashrc
    fi
}

# Install Homebrew on OS X systems.
installHomebrew(){
    echo "It seems that you don't have Homebrew installed on your system."
    echo "Homebrew is necessary (and highly recommended!) to install some features on Mac OS X systems."

    CONFIRMED=$SILENT
    
    if [ "$CONFIRMED" = 0 ]; then
        echo "Do you want to install Homebrew now?"
        
        select byn in Yes No
        do
            case "$byn" in
                Yes)
                    CONFIRMED=1
                    break
                    ;;
                No)
                    echo "Ignore Homebrew setup."
                    break
                    ;;
            esac
        done
    fi

    if [ "$CONFIRMED" = 1 ]; then
        PKG_MANAGER="brew"
        ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)"
        export PATH=$PATH:/usr/local/share/npm/bin/
        refreshEnvironment
    fi
}

# INSTALL MISSING DEPENDENCIES
# -------------------------------------------------------------------------

# Install a package. If second argument is 1, use NPM to install,
# otherwise use the default package manager.
installPackage(){
    echo "Installing $1..."

    if [ "$2" = 1 ]; then
        sudo npm install -g "$1"
    elif [ "$PKG_MANAGER" = "yum" ]; then
        sudo yum --enablerepo=updates-testing install -y "$1"
    elif [ "$PKG_MANAGER" = "apt-get" ]; then
        sudo apt-get --ignore-missing -y install "$1"
    else
        brew install "$1"
    fi

    refreshEnvironment
}

# Confirm package installation by prompting the user, or auto installing if SILENT is 1.
confirmInstall(){
    if [ "$SILENT" = 1 ]; then
        installPackage $1 $2
        return 1
    else
        echo ""
        echo "Do you want to install $1 now?"

        select iyn in Yes No
        do
            case "$iyn" in
                Yes)
                    installPackage $1 $2
                    break
                    ;;
                No)
                    echo "Ignore dependency: $1"
                    break
                    ;;
            esac
        done
    fi
}

# DEPENDENCY CHECK
# -------------------------------------------------------------------------

# Prints a message about a dependency.
# First argument defines if dependency is optional (0 is required, 1 is optional).
aboutDependency(){
    echo ""
    echo "$1"

    if [ "$2" -eq 1 ]; then
        echo "It's optional but recommended."
    fi
}

# Check for a dependency using the which command.
# Dependency name is passed as an argument.
checkDependency(){
    type "$1"&> /dev/null;
}

# Check if GIT is installed (git: required).
checkGit(){
    if checkDependency "git"; then
        echo "GIT is installed!"
    else
        aboutDependency "The System App needs GIT to be able to download and update its source code." 0
        confirmInstall "git" 0
    fi
}

# Check if Node.js is installed (node: required).
checkNode(){
    if checkDependency "node"; then
        echo "Node.js is installed!"
    else
        aboutDependency "The System App needs Node.js to run." 0
        if [ "$PKG_MANAGER" = "brew" ]; then
            confirmInstall "node" 0
        else
            if [ "$PKG_MANAGER" = "apt-get" ]; then
                checkNodeAptRepo
            fi
            confirmInstall "nodejs" 0
        fi
    fi
}

# Check if Node.js repository is set on APT.
checkNodeAptRepo(){
    echo "Before installing Node.js, you must add the chris-lea/node.js repository to your system."

    CONFIRMED=$SILENT
    
    if [ "$CONFIRMED" = 0 ]; then
        echo "Do you want to add the node.js repository now?"
        
        select nyn in Yes No
        do
            case "$nyn" in
                Yes)
                    CONFIRMED=1
                    break
                    ;;
                No)
                    echo "Skip (do not add chris-lea/node.js repository)."
                    break
                    ;;
            esac
        done
    fi

    if [ "$CONFIRMED" = 1 ]; then
        sudo add-apt-repository -y ppa:chris-lea/node.js
        sudo apt-get update
    fi
}

# Check if NPM is installed (npm: required).
checkNpm(){
    if checkDependency "npm"; then
        echo "NPM is installed!"
    else
        aboutDependency "The Cube App needs NPM to maintain its Node.js modules." 0
        confirmInstall "npm" 0
    fi
}

# Check if MongoDB is installed (mongo: required).
#checkMongo(){
#    if checkDependency "mongo"; then
#        echo "MongoDB is installed!"
#    else
#        aboutDependency "The System App needs MongoDB to store data. If you don't want to install MongoDB locally, you can use a free hosted version at http://mongolab.com." 0
#        if [ "$PKG_MANAGER" = "brew" ]; then
#            confirmInstall "mongo" 0
#        else
#            if [ "$PKG_MANAGER" = "apt-get" ]; then
#                checkMongoAptRepo
#                confirmInstall "mongodb-10gen" 0
#            else
#                checkMongoYumRepo
#                confirmInstall "mongodb" 0
#            fi
#        fi
#    fi
#}

# Check if MongoDB repository is set on APT.
#checkMongoAptRepo(){
#    echo "Before installing MongoDB, you must add the 10gen repository to your system."
#
#    CONFIRMED=$SILENT
#
#    if [ "$CONFIRMED" = 0 ]; then
#        echo "Do you want to add the 10gen repository now?"
#
#        select myn in Yes No
#        do
#            case "$myn" in
#                Yes)
#                    CONFIRMED=1
#                    break
#                    ;;
#                No)
#                    echo "Skip (do not add 10gen repository)."
#                    break
#                    ;;
#            esac
#        done
#    fi
#
#    if [ "$CONFIRMED" = 1 ]; then
#        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
#        sudo sh -c "echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' > /etc/apt/sources.list.d/10gen.list"
#        sudo apt-get update
#    fi
#}

# Check if MongoDB repository is set on YUM.
#checkMongoYumRepo(){
#    echo "Before installing MongoDB, you must add the 10gen repository to your system."
#
#    CONFIRMED=$SILENT
#    
#    if [ "$CONFIRMED" = 0 ]; then
#        echo "Do you want to add the 10gen repository now?"
#        
#        select myn in Yes No
#        do
#            case "$myn" in
#                Yes)
#                    CONFIRMED=1
#                    break
#                    ;;
#                No)
#                    echo "Skip (do not add 10gen repository)."
#                    break
#                    ;;
#            esac
#        done
#    fi
#
#    if [ "$CONFIRMED" = 1 ]; then
#        sudo sh -c "echo -e '[10gen]\nname=10gen Repository\nbaseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64\ngpgcheck=0\nenabled=1' > /etc/yum.repos.d/10gen.repo"
#    fi
#}

# Check if Maven is installed (mongo: required).
checkMaven(){
    if checkDependency "mvn"; then
        echo "Maven is installed!"
    else
        aboutDependency "The Cube App needs Maven to build the Solr database." 0
        if [ "$PKG_MANAGER" = "brew" ]; then
            confirmInstall "maven" 0
        else
            if [ "$PKG_MANAGER" = "apt-get" ]; then
                confirmInstall "maven2" 0
            else
                checkMavenYumRepo
                confirmInstall "maven2" 0
            fi
        fi
    fi
}

# Check if Maven repository is set on YUM.
checkMongoYumRepo(){
    echo "Before installing Maven, you must add the jpackage-generic repository to your system."

    CONFIRMED=$SILENT

    if [ "$CONFIRMED" = 0 ]; then
        echo "Do you want to add the jpackage-generic repository now?"

        select myn in Yes No
        do
            case "$myn" in
                Yes)
                    CONFIRMED=1
                    break
                    ;;
                No)
                    echo "Skip (do not add jpackage-generic repository)."
                    break
                    ;;
            esac
        done
    fi

    if [ "$CONFIRMED" = 1 ]; then
        sudo sh -c "echo -e '[jpackage-generic-free]\nname=JPackage generic free\nbaseurl=http://mirrors.dotsrc.org/jpackage/6.0/generic/free/\ngpgcheck=0\nenabled=1' > /etc/yum.repos.d/jpackage-generic-free.repo"
        sudo sh -c "echo -e '[jpackage-generic-devel]\nname=JPackage Generic Developer\nbaseurl=http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-6Server/SRPMS\ngpgcheck=0\nskip_if_unavailable=1\nenabled=1' > /etc/yum.repos.d/jpackage-generic-devel.repo"
    fi
}

# Check if forever is installed (forever: optional).
checkForever(){
    if checkDependency "forever"; then
        echo "Forever is installed!"
    else
        aboutDependency "Forever is a Node.js module that helps you starting and stopping the server as a service." 1
        confirmInstall "forever" 1
    fi
}

# Check if Docco is installed (docco: optional).
checkDocco(){
    if checkDependency "docco"; then
        echo "Docco is installed!"
    else
        aboutDependency "Docco is necessary to update the System App documentation." 1
        confirmInstall "docco" 1
    fi
}

# Check if node is installed (imagemagick: optional).
checkImageMagick(){
    if checkDependency "convert"; then
        echo "ImageMagick is installed!"
    else
        aboutDependency "ImageMagick is necessary to generate map thumbnails." 1
        confirmInstall "imagemagick" 0
    fi
}


# POST INSTALL
# -------------------------------------------------------------------------

# Download latest source code from GitHub.
downloadFromGit(){
    if [ ! -d ./.git ]; then
        echo "It seems you have not downloaded the Cube App source from its GIT repository."

        CONFIRMED=$SILENT
        
        if [ "$CONFIRMED" = 0 ]; then
            echo "Do you want to download the latest source to the current folder now?"
            
            select dyn in Yes No
            do
                case "$dyn" in
                    Yes)
                        CONFIRMED=1
                        break
                        ;;
                    No)
                        echo "Do not download the source files!"
                        break
                        ;;
                esac
            done
        fi
        
        if [ "$CONFIRMED" = 1 ]; then
            echo "Clone the Cube App repository..."
            git clone https://github.com/zalando/cube.git ./cube_latest
            rm -f cube_latest/install.sh
            mv -f cube_latest/* ./
            mv -f cube_latest/.git ./
            rm -fr cube_latest
            echo "Installing Node.js modules..."
            sudo npm install
        fi
    fi
}

# Tell the user how to start the server.
howToStartServer(){
    echo ""

    if [ "$OS_TYPE" = "Darwin" ]; then
        echo "Note to Mac OS X users!"
        echo "Please make sure that the NPM bin directory is added to your PATH environment variable."
        echo "You can edit your ~/.bash_profile and add the following line:"
        echo ""
        echo "export PATH=\$PATH:/usr/local/share/npm/bin/"
        echo ""
        echo "This step is optional but recommended, otherwise you might not be able to execute Node modules and commands."
    fi

    echo "If no problems were found you should be able to start the Cube App by running the command:"
    echo "$ coffee cube.coffee"
    echo ""
    echo "If you have installed the forever module, please use:"
    echo "$ forever start -c coffee cube.coffee"
    echo ""
    echo "You also need to start the solr database in a new terminal."
    echo "Please cd into the solr directory and run use:"
    echo "$ mvn clean install tomcat:run-war -Pdevelopment"
    echo ""
    echo "Enjoy :-)"
}

# RUN SCRIPT
# -------------------------------------------------------------------------
# Init the install script by running the sub functions.

echo "CUBE APP INSTALL SCRIPT"
echo ""
echo "This script will help you installing and configuring the Zalando Cube App."
echo "If you have problems please get help on our project page:"
echo ""
echo "http://cubeapp.io"
echo ""

if [ "$1" = "-y" ]; then
    SILENT=1
    echo "Running in silent mode: all prompts will be automatically accepted!"
else
    echo "During the execution, you'll be asked to confirm the installation of specific packages."
    echo "Pressing 1 selects Yes, and 2 selects No."
fi

echo ""

checkRoot
checkEnvironment

checkGit
checkNode
checkNpm
checkMaven
#checkMongo
checkForever
checkDocco
checkImageMagick

downloadFromGit
howToStartServer
