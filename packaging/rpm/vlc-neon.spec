# VLC Neon: unofficial VLC 4 build installed under /opt/vlc-neon so it never
# clashes with Fedora's (or RPM Fusion's) vlc package.
%global neon_prefix /opt/vlc-neon
%global vlc_commit  e77e49b5dff7484dbf70cd1540a6a568e1890280
# Private libraries/plugins are not offered to other packages...
%global __provides_exclude_from ^%{neon_prefix}/.*$
# ...and the binaries' links to them are satisfied by this package itself.
%global __requires_exclude ^libvlc[a-z_]*\\.so.*$
%global debug_package %{nil}

Name:           vlc-neon
Version:        1.0.0
Release:        1%{?dist}
Summary:        VLC media player with seek previews, Picture-in-Picture and extra controls
License:        GPL-2.0-or-later AND LGPL-2.1-or-later AND OFL-1.1
URL:            https://github.com/TaoufikGFX/vlc-neon
# Complete corresponding source: pinned upstream VLC + patches + build scripts
Source0:        %{url}/releases/download/v%{version}/vlc-neon-%{version}-source.tar.gz
ExclusiveArch:  x86_64 aarch64

BuildRequires:  gcc gcc-c++ make git-core meson >= 1.10 ninja-build pkgconf-pkg-config
BuildRequires:  flex bison gettext-devel desktop-file-utils libappstream-glib
BuildRequires:  qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel
BuildRequires:  qt6-qtsvg-devel qt6-qtshadertools-devel qt6-qtwayland-devel
BuildRequires:  wayland-devel wayland-protocols-devel libxkbcommon-devel
BuildRequires:  mesa-libEGL-devel mesa-libGL-devel libva-devel libvdpau-devel
BuildRequires:  libavcodec-free-devel libavformat-free-devel libavutil-free-devel libswscale-free-devel
BuildRequires:  libass-devel libebml-devel libmatroska-devel libmad-devel libdvbpsi-devel
BuildRequires:  libdvdread-devel libdvdnav-devel libgcrypt-devel libgpg-error-devel
BuildRequires:  lua-devel libarchive-devel libpng-devel libjpeg-turbo-devel
BuildRequires:  pipewire-devel pulseaudio-libs-devel alsa-lib-devel
BuildRequires:  libX11-devel libxcb-devel xcb-util-keysyms-devel dbus-devel
BuildRequires:  freetype-devel fribidi-devel harfbuzz-devel fontconfig-devel
BuildRequires:  flac-devel libogg-devel libvorbis-devel opus-devel speex-devel libtheora-devel
BuildRequires:  libsamplerate-devel libxml2-devel zlib-devel libvpx-devel libdav1d-devel
BuildRequires:  libnotify-devel libsecret-devel gnutls-devel taglib-devel

# Qt private API: the Qt plugin needs the Qt minor version it was built with
# (patch updates are fine; a new minor version needs a new VLC Neon build)
%{?_qt6:Requires: %{_qt6}%{?_isa} >= %{_qt6_version}}
%{?_qt6:Requires: %{_qt6}%{?_isa} < %(echo %{_qt6_version} | awk -F. '{print $1"."$2+1}')}
Requires:       hicolor-icon-theme

%description
VLC Neon is an unofficial build of the VLC 4 media player with a neon identity
and extra everyday controls: thumbnail previews on the seek bar, a separate
Picture-in-Picture window, speed presets, repeat counts (1-5 or unlimited),
volume boost up to 300 %%, resume prompts and per-file settings.

It installs into %{neon_prefix} with its own command (vlc-neon), settings
(~/.config/vlc-neon) and desktop entry, so it runs side by side with VLC.

Based on VLC media player by VideoLAN. Not an official VideoLAN product.

%prep
%autosetup -n vlc-neon-%{version}

%build
scripts/build.sh --prefix %{neon_prefix} --destdir %{_builddir}/neon-stage \
    --builddir %{_builddir}/neon-build --jobs %{_smp_build_ncpus}

%install
cp -a %{_builddir}/neon-stage/. %{buildroot}/
# Headers, pkg-config and static bits are not needed to run the player
rm -rf %{buildroot}%{neon_prefix}/include %{buildroot}%{neon_prefix}/lib64/pkgconfig
find %{buildroot}%{neon_prefix} -name '*.a' -delete

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/org.VideoLAN.VLCNeon.desktop
appstream-util validate-relax --nonet %{buildroot}%{_metainfodir}/org.VideoLAN.VLCNeon.metainfo.xml

%files
%license COPYING COPYING.LIB
%doc README.md CHANGELOG.md
%{_bindir}/vlc-neon
%{neon_prefix}
%{_datadir}/applications/org.VideoLAN.VLCNeon.desktop
%{_metainfodir}/org.VideoLAN.VLCNeon.metainfo.xml
%{_datadir}/icons/hicolor/*/apps/vlc-neon.*
%{_datadir}/kwin/scripts/vlc-neon-pip

%changelog
* Sat Oct 10 2026 Taoufik Mouadab <27153304+TaoufikGFX@users.noreply.github.com> - 1.0.0-1
- First public release, based on VLC 4.0.0-dev (upstream commit e77e49b5)
