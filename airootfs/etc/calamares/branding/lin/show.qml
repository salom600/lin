/* =========================================================================
   Lin OS — Calamares slideshow
   =========================================================================
   A simple QML slideshow shown during the install. Displays:
   - Progress text
   - Cycling list of features
   ========================================================================= */

import QtQuick 2.0;
import QtQuick.Window 2.0;

Item {
    id: root
    anchors.fill: parent

    // Background gradient (Lin OS accent colors)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1d29" }
            GradientStop { position: 1.0; color: "#2d1b3d" }
        }
    }

    // Title
    Text {
        id: title
        anchors.top: parent.top
        anchors.topMargin: 60
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Installing Lin OS"
        color: "#ffffff"
        font.family: "Inter"
        font.pixelSize: 36
        font.weight: Font.DemiBold
    }

    // Subtitle
    Text {
        id: subtitle
        anchors.top: title.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Your modern, lightweight Linux is being set up."
        color: "#a0a3b1"
        font.family: "Inter"
        font.pixelSize: 16
    }

    // Feature carousel
    ListView {
        id: featureList
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: 200
        model: features
        delegate: featureDelegate
        orientation: ListView.Vertical
        clip: true
        // Cycle through features every 3 seconds
        Timer {
            interval: 3000
            running: true
            repeat: true
            onTriggered: {
                if (featureList.currentIndex < featureList.count - 1) {
                    featureList.currentIndex++;
                } else {
                    featureList.currentIndex = 0;
                }
            }
        }
    }

    ListModel {
        id: features
        ListElement { feature: "Lightweight";    desc: "Idle at ~150 MB RAM, 0% CPU" }
        ListElement { feature: "Sleek";          desc: "Windows 11-style UI with transparency" }
        ListElement { feature: "App Store";      desc: "pacman, AUR, Flatpak, AppImage — all in one place" }
        ListElement { feature: "Gaming-ready";   desc: "Steam, Proton, Vulkan drivers pre-installed" }
        ListElement { feature: "Wayland";        desc: "Modern, secure, gestures built in" }
        ListElement { feature: "User-friendly";  desc: "Designed for Windows migrants" }
    }

    Component {
        id: featureDelegate
        Item {
            width: featureList.width
            height: 80
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 20
                text: feature
                color: "#ffffff"
                font.family: "Inter"
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 20
                text: desc
                color: "#a0a3b1"
                font.family: "Inter"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // Bottom progress hint
    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        text: "This usually takes 3 to 8 minutes"
        color: "#6b7280"
        font.family: "Inter"
        font.pixelSize: 14
    }
}
