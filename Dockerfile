FROM rockylinux:8 as builder

#Taken from: https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/Build-on-CentOS-7.x

RUN dnf -y install dnf-plugins-core; \
    dnf config-manager --set-enabled devel; \
    dnf -y group install "Development Tools"; \
    dnf -y builddep pulseaudio

RUN dnf -y install epel-release; \
    dnf -y install pulseaudio pulseaudio-libs pulseaudio-libs-devel jack-audio-connection-kit-devel

RUN dnf download --source pulseaudio; \
    rpm --install pulseaudio*.src.rpm;

RUN sed -i '1 i\%global enable_jack 1' /root/rpmbuild/SPECS/pulseaudio.spec; \
    rpmbuild -bb /root/rpmbuild/SPECS/pulseaudio.spec; \
    rpm -i /root/rpmbuild/RPMS/x86_64/pulseaudio-module-jack-14*.rpm;

RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git; \
    cd pulseaudio-module-xrdp; \
    ./bootstrap && ./configure PULSE_DIR=/root/rpmbuild/BUILD/pulseaudio-14.0; \
    make && make install;

#Adapted from https://github.com/danielguerra69/alpine-xfce4-xrdp

FROM rockylinux:8
LABEL Name=rocky-xfce4-xrdp Version=8.0.2
ENV container docker

RUN dnf -y install epel-release;

# Install XFCE4
RUN dnf -y install \
        Thunar \
        fuse \
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
        xfwm4;

# Install XRDP
RUN dnf -y install xrdp xorgxrdp;
ADD etc/sysconfig /etc/sysconfig

# Install PulseAudio
RUN dnf -y install \
        pulseaudio \
        pulseaudio-libs \
        alsa-plugins-pulseaudio \
        pulseaudio-module-x11;
COPY --from=builder /usr/lib64/pulse-14.0/modules /usr/lib64/pulse-14.0/modules
COPY --from=builder /root/rpmbuild/RPMS/x86_64/pulseaudio-module-jack-14*.rpm /root
COPY --from=builder /usr/libexec/pulseaudio-module-xrdp/load_pa_modules.sh /usr/libexec/pulseaudio-module-xrdp/load_pa_modules.sh
COPY --from=builder /etc/xdg/autostart/pulseaudio-xrdp.desktop /etc/xdg/autostart/pulseaudio-xrdp.desktop
ADD etc/pulse /etc/pulse
#RUN rpm -i /root/pulseaudio-module-jack-14*.rpm;


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
    systemctl enable xrdp-sesman; \
    systemctl unmask systemd-logind.service

# Setup LANG
RUN dnf -y install glibc-langpack-en; \
    sed -i -e 's/C.UTF-8/en_US.utf8/' /etc/locale.conf;

RUN dnf -y autoremove; \
    dnf -y clean all;

# Add a user
#RUN adduser -c Rivendell\ Audio --groups audio,wheel rduser && echo rduser:rduser | chpasswd
ADD 999999_001.wav /tone.wav


EXPOSE 3389

CMD ["/usr/sbin/init"]
