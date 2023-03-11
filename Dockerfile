ARG XRDPPULSE_VER="0.6"
ARG PULSE_VER="10.0"

FROM centos:7 as builder

#Taken from: https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/Build-on-CentOS-7.x

RUN yum -y groupinstall "Development Tools"; \
    yum -y install rpmdevtools yum-utils; \
    rpmdev-setuptree;

RUN yum -y install epel-release; \
    yum -y install pulseaudio pulseaudio-libs pulseaudio-libs-devel jack-audio-connection-kit-devel; \
    yum-builddep -y pulseaudio

RUN yumdownloader --source pulseaudio; \
    rpm --install pulseaudio*.src.rpm; \
    rpmbuild -bb /root/rpmbuild/SPECS/pulseaudio.spec;

RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git; \
    cd pulseaudio-module-xrdp; \
    ./bootstrap && ./configure PULSE_DIR=/root/rpmbuild/BUILD/pulseaudio-10.0; \
    make && make install;

#Adapted from https://github.com/danielguerra69/alpine-xfce4-xrdp

FROM centos:7
LABEL Name=rocky-xfce4-xrdp Version=0.0.1
ENV container docker

# Update system, install init system and add repo
# Install PulseAudio
# Install XFCE4

# Install XRDP
RUN yum -y install epel-release; \
    yum -y install pulseaudio pulseaudio-libs pulseaudio-module-jack; \
    yum -y install \
        Thunar \
        openssh-askpass \
        thunar-archive-plugin \
        thunar-volman \
        tumbler \
        xfce-polkit \
        xfce4-appfinder \
        xfce4-panel \
        xfce4-pulseaudio-plugin \
        xfce4-session \
        xfce4-settings \
        xfce4-terminal \
        xfconf \
        xfdesktop \
        xfwm4; \
    yum -y install xrdp xorgxrdp; \
    yum -y install alsa-plugins-pulseaudio pulseaudio-module-x11; \
    yum -y remove network-manager-applet xfce4-power-manager xfce4-screensaver NetworkManager-wifi upower; \
    yum -y autoremove; \
    yum -y clean all;

# Install PulseAudio
COPY --from=builder /usr/lib64/pulse-10.0/modules /usr/lib64/pulse-10.0/modules

#
# Configure systemd
#
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
    systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /usr/lib/systemd/system/multi-user.target.wants/systemd-update-utmp-runlevel.service; \
    rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]

RUN systemctl set-default multi-user.target; \
    systemctl enable xrdp; \
    systemctl enable xrdp-sesman;

ADD etc/xrdp /etc/xrdp
ADD etc/skel /etc/skel
ADD usr /usr
ADD 999999_001.wav /tone.wav

# Add a user
#RUN adduser -c Rivendell\ Audio --groups audio,wheel rduser && echo rduser:rduser | chpasswd

EXPOSE 3389

CMD ["/usr/sbin/init"]
